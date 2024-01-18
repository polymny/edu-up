import os
import sys
import json
import hashlib
import re
from typing import *

from utils import *
from vars import *


class Producer:
    """Producer class."""

    def __init__(self,
                 capsule_id: int,
                 ):
        """Initialize the producer class

        Args:
            capsule_id (int): Capsule index.

        Producer is first waiting for the capsule info to be sent in the stdin.

        The capsule info is a json object with the following structure:
        {
            structure: [GOS],
            sound_track: {capsule's sound track}
            produced_hash: {hash of the produced capsule, might be None}
        }
        """
        self.capsule_id = capsule_id

        self.capsule_info: dict = json.load(sys.stdin)
        self.structure = self.capsule_info.get('structure', [])
        self.soundtrack = self.capsule_info.get('soundtrack', None)
        self.produced_hash = self.capsule_info.get('produced_hash', None)

        self.current_frame_count = 0
        self.total_frame_count = None

        self.data_path = get_config(keys=('default', 'data_path'))
        self.capsule_path = os.path.join(self.data_path, str(capsule_id))
        self.assets_path = os.path.join(self.capsule_path, "assets")
        self.produced_path = os.path.join(self.capsule_path, "produced")
        self.tmp_path = os.path.join(self.capsule_path, "tmp")
        if not os.path.exists(self.produced_path):
            os.makedirs(self.produced_path)
        if not os.path.exists(self.tmp_path):
            os.makedirs(self.tmp_path)

        self.stream_spec_count = 0

    def run_ffmpeg(self,
                   cmd: str,
                   ) -> subprocess.Popen[str]:
        """Runs a ffmpeg command.

        Args:
            cmd (str): The ffmpeg command.

        Returns:
            Popen: The ffmpeg process.
        """

        # Run the command.
        p = subprocess.Popen(f"ffmpeg -loglevel error -progress - -nostats -y {cmd}",
                             shell=True,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE,
                             universal_newlines=True)

        # Get the progress.
        frame_count = 0
        for line in iter(p.stdout.readline, ""):
            match = re.search(r"frame=(\d+)", line)
            if not match:
                continue
            frame_count = int(match.group(1))
            val = (self.current_frame_count + frame_count) / \
                self.total_frame_count
            val = min(1, max(0, val))
            sys.stdout.write(f"{val:.2f}\n")
            sys.stdout.flush()

        p.wait()

        # Update the frame count.
        self.current_frame_count += frame_count

        return p

    def new_stream_spec(self) -> str:
        """Returns a stream specifier.

        Returns:
            str: Stream specifier.

        """
        spec = f"[stream_spec_{self.stream_spec_count}]"
        self.stream_spec_count += 1
        return spec

    def add_filter(self,
                   input_specs: "Iterable[str] | str",
                   filter: str,
                   nb_outputs: int = 1,
                   ) -> "List[str] | str":
        """Adds a filter.

        Args:
            input_specs (Iterable[str] | str): Input stream specifiers.
            filter (str): Filter.
            nb_outputs (int, optional): Number of outputs. Defaults to 1.

        Returns:
            List[str]: Output stream specifiers.
        """
        # Convert to list if needed.
        if isinstance(input_specs, str):
            input_specs = [input_specs]

        # Get the new stream specifiers.
        new_specs = [self.new_stream_spec() for _ in range(nb_outputs)]

        # Add the filter.
        filter = f"{''.join(input_specs)}{filter}{''.join(new_specs)}"
        self.filters.append(filter)

        return new_specs if nb_outputs > 1 else new_specs[0]

    def produce_capsule(self) -> str:
        """Produces the capsule.

        Returns:
            str: Path to the produced capsule.

        The produced video is saved in `{data_path}/{capsule_id}/produced/capsule.mp4`.

        """
        # Skip if the produced hash is the same.
        self.capsule_info['produced_hash'] = None
        json_thing = json.dumps(self.capsule_info,
                                separators=(',', ':'),
                                sort_keys=True).encode()
        hash_thing = hashlib.sha256(json_thing).hexdigest()
        if hash_thing == self.produced_hash:
            print("Capsule already produced: production skipped.", file=sys.stderr)
            return os.path.join(self.capsule_path, "produced", f"capsule.mp4")

        # Compute total frame count.
        self.total_frame_count = FRAME_RATE * self.get_capsule_duration()
        for gos_id, gos in enumerate(self.structure):
            gos_hash = gos['produced_hash']
            gos['produced_hash'] = None
            json_thing = json.dumps(gos,
                                    separators=(',', ':'),
                                    sort_keys=True).encode()
            hash_thing = hashlib.sha256(json_thing).hexdigest()
            gos['produced_hash'] = gos_hash
            if hash_thing == gos_hash:
                continue
            self.total_frame_count += FRAME_RATE * \
                self.get_gos_duration(gos_id)

        # Produce the GOSs.
        gos_paths = []
        for gos_id in range(len(self.structure)):
            gos_path = self.produce_gos(gos_id)
            gos_paths.append(gos_path)

        self.inputs = [f"-i {gos_path}" for gos_path in gos_paths]
        self.filters = []
        self.tmp_files = []
        self.audio_specs = []

        # Concatenate the GOSs.
        nb_gos = len(gos_paths)
        gos_specs = [f"[{gos_id}:v][{gos_id}:a]" for gos_id in range(nb_gos)]
        if len(gos_paths) > 1:
            # Concatenate the videos.
            concat_filter = f"concat=n={nb_gos}:v=1:a=1"
            output_spec, audio_spec = self.add_filter(
                gos_specs, concat_filter, nb_outputs=2)
            self.audio_specs.append(audio_spec)
        else:
            output_spec = "[0:v]"
            self.audio_specs.append("[0:a]")

        # Add the soundtrack.
        if self.soundtrack is not None:
            soudtrack_spec = self.compose_soundtrack()
            self.audio_specs.append(soudtrack_spec)

        # Concatenate the audio.
        audio_spec = self.compose_audio()

        # Remove the brackets if there is only one stream.
        output_spec = output_spec[1:-1] if ":" in output_spec else output_spec
        audio_spec = audio_spec[1:-1] if ":" in audio_spec else audio_spec

        # Produce the capsule.
        output_path = os.path.join(
            self.capsule_path, "produced", f"capsule.mp4")
        complexe_filter = f"-filter_complex \"{';'.join(self.filters)}\"" if len(
            self.filters) > 0 else ""
        cmd = f"{' '.join(self.inputs)} \
                {complexe_filter} \
                -map \"{output_spec}\" \
                -map \"{audio_spec}\" \
                -c:v {VCODEC} -pix_fmt {PIXEL_FORMAT} -r {FRAME_RATE} \
                -c:a {ACODEC} -ar {ARATE} -b:a {ABITRATE} \
                -movflags +faststart \
                {output_path}"
        print(cmd, file=sys.stderr)
        p = self.run_ffmpeg(cmd)

        # Remove the tmp files.
        for tmp_file in self.tmp_files:
            os.remove(tmp_file)

        # Check the return code.
        if p.returncode != 0:
            raise RuntimeError(
                f"Error producing GOS {gos_id} of capsule {self.capsule_id}.\n{p.stderr.read()}")

        return output_path

    def compose_soundtrack(self) -> str:
        """Composes the soundtrack.

        Returns:
            str: Output spec.
        """
        soundtrack_uuid = self.soundtrack['uuid']
        soundtrack_path = os.path.join(
            self.assets_path, f"{soundtrack_uuid}.m4a")

        # Get the duration of the video and the soundtrack.
        capsule_duration = round(self.get_capsule_duration(), 3)
        soundtrack_duration = get_duration(soundtrack_path)

        # Add the soundtrack to the inputs.
        self.inputs.append(f"-i {soundtrack_path}")
        soundtrack_spec = f"[{len(self.inputs) - 1}:a]"

        # Apply fade in and fade out.
        fadeout_start = round(soundtrack_duration -
                              SOUNDTRACK_FADE_DURATION, 3)
        fade_filter = f"afade=t=in:st=0:d={SOUNDTRACK_FADE_DURATION},\
            afade=t=out:st={fadeout_start}:d={SOUNDTRACK_FADE_DURATION}"
        soundtrack_spec = self.add_filter(soundtrack_spec, fade_filter)

        # Apply volume.
        volume = round(self.soundtrack['volume'], 3)
        if 0.0 < volume < 1.0:
            volume_filter = f"volume={volume}"
            soundtrack_spec = self.add_filter(soundtrack_spec, volume_filter)

        # Split the audio.
        nb_repeats = int(capsule_duration / soundtrack_duration) + 1
        repeat_filter = f"asplit={nb_repeats}"
        soundtrack_specs = self.add_filter(
            soundtrack_spec, repeat_filter, nb_repeats)

        # Join the audio.
        join_filter = f"concat=n={nb_repeats}:v=0:a=1"
        soundtrack_spec = self.add_filter(soundtrack_specs, join_filter)

        # Add the last fade out.
        fadeout_start = round(capsule_duration - SOUNDTRACK_FADE_DURATION, 3)
        fade_filter = f"afade=t=out:st={fadeout_start}:d={SOUNDTRACK_FADE_DURATION}"
        soundtrack_spec = self.add_filter(soundtrack_spec, fade_filter)

        # Trim the end of the audio.
        trim_filter = f"atrim=0:{capsule_duration}"
        soundtrack_spec = self.add_filter(soundtrack_spec, trim_filter)

        return soundtrack_spec

    def produce_gos(self,
                    gos_id: int,
                    ) -> str:
        """Produces the GOS.

        Args:
            gos_id (int): GOS index.

        Returns:
            str: Output path.

        The produced video is saved in `{data_path}/{capsule_id}/produced/{hash_thing}.mp4`.

        """
        if self.total_frame_count is None:
            self.total_frame_count = FRAME_RATE * self.get_gos_duration(gos_id)

        gos_structure = self.structure[gos_id]
        self.inputs = []
        self.filters = []
        self.tmp_files = []
        self.audio_specs = []

        # Skip if the produced hash is the same.
        gos_hash = gos_structure['produced_hash']
        gos_structure['produced_hash'] = None
        json_thing = json.dumps(gos_structure,
                                separators=(',', ':'),
                                sort_keys=True).encode()
        hash_thing = hashlib.sha256(json_thing).hexdigest()
        if hash_thing == gos_hash:
            # Update progress.
            val = self.current_frame_count / self.total_frame_count
            sys.stdout.write(f"{val:.2f}\n")
            sys.stdout.flush()

            print(
                f"GOS {gos_id} already produced: production skipped.", file=sys.stderr)
            return os.path.join(self.produced_path, f"{hash_thing}.mp4")

        nb_slides = len(gos_structure['slides'])

        # Add silence to ensure GOS audio.
        gos_duration = self.get_gos_duration(gos_id)
        self.inputs.append(
            f"-f lavfi -t {gos_duration} -i anullsrc=channel_layout=stereo:sample_rate={ARATE}")
        silence_spec = f"[{len(self.inputs) - 1}:a]"
        self.audio_specs.append(silence_spec)

        # Compose the slides.
        slides_spec = []
        for slide_id in range(nb_slides):
            slide_spec = self.compose_slide(gos_id, slide_id)
            slides_spec.append(slide_spec)

        # Concat the slides.
        if nb_slides > 1:
            concat_filter = f"concat=n={nb_slides}:v=1:a=0"
            output_spec = self.add_filter(slides_spec, concat_filter)
        else:
            output_spec = slide_spec

        # Add the pointer.
        record = gos_structure['record']
        if record is not None:
            pointer_uuid = record['pointer_uuid']
            if pointer_uuid is not None:
                pointer_spec = self.compose_pointer(gos_id)

                # Overlay the pointer.
                overlay_filter = f"overlay"
                output_spec = self.add_filter(
                    [output_spec, pointer_spec], overlay_filter)

        # Add the record.
        if record is not None:

            # Compose the record.
            record_spec = self.compose_record(gos_id)

            # Overlay the record if needed.
            if (record['size'] is not None
                    and gos_structure['webcam_settings']['type'] != 'disabled'):
                overlay_x, overlay_y = self.get_record_position(gos_id)
                overlay_filter = f"overlay={overlay_x}:{overlay_y}"
                output_spec = self.add_filter(
                    [output_spec, record_spec], overlay_filter)

        # Compose the audio.
        audio_spec = self.compose_audio()

        # Remove the brackets if there is only one stream.
        output_spec = output_spec[1:-1] if ":" in output_spec else output_spec
        audio_spec = audio_spec[1:-1] if ":" in audio_spec else audio_spec

        # Produce the GOS.
        output_path = os.path.join(self.produced_path, f"{hash_thing}.mp4")
        filter_complex = f"-filter_complex \"{';'.join(self.filters)}\"" if len(
            self.filters) > 0 else ""
        cmd = f"{' '.join(self.inputs)} \
                {filter_complex} \
                -map \"{output_spec}\" \
                -map \"{audio_spec}\" \
                -c:v {VCODEC} -pix_fmt {PIXEL_FORMAT} -r {FRAME_RATE} \
                -c:a {ACODEC} -ar {ARATE} -b:a {ABITRATE} \
                -movflags +faststart \
                {output_path}"
        print(cmd, file=sys.stderr)
        p = self.run_ffmpeg(cmd)

        # Remove the tmp files.
        for tmp_file in self.tmp_files:
            os.remove(tmp_file)

        # Check the return code.
        if p.returncode != 0:
            raise RuntimeError(
                f"Error producing GOS {gos_id} of capsule {self.capsule_id}.\n{p.stderr.read()}")

        return output_path

    def compose_pointer(self,
                        gos_id: int,
                        ) -> str:
        """Composes the pointer.

        Args:
            gos_id (int): GOS index.

        Returns:
            str: Output spec.
        """
        gos_structure = self.structure[gos_id]
        record = gos_structure['record']
        pointer_uuid = record['pointer_uuid']
        pointer_path = os.path.join(self.assets_path, f"{pointer_uuid}.webm")

        # Add the pointer.
        self.inputs.append(f"-i {pointer_path}")
        pointer_spec = f"[{len(self.inputs) - 1}:v]"

        # Black keying.
        black_keying_filter = f"colorkey=0x{POINTER_COLOR}:{POINTER_SIMILARITY}:{POINTER_BLEND}"
        pointer_spec = self.add_filter(pointer_spec, black_keying_filter)

        return pointer_spec

    def get_capsule_duration(self) -> float:
        """Gets the capsule duration. (in seconds)

        Returns:
            float: Capsule duration. (in seconds)
        """
        capsule_duration = 0.0
        for gos_id in range(len(self.structure)):
            gos_duration = self.get_gos_duration(gos_id)
            capsule_duration += gos_duration
        return capsule_duration

    def get_gos_duration(self,
                         gos_id: int,
                         ) -> float:
        """Gets the GOS duration. (in seconds)

        Args:
            gos_id (int): GOS index.

        Returns:
            float: GOS duration. (in seconds)
        """
        events = self.structure[gos_id]['events']
        if len(events) == 0:
            # No record so the duration is the sum of the slides duration.
            # Extras are considered in the slides duration.
            gos_duration = 0.0
            for slide_id in range(len(self.structure[gos_id]['slides'])):
                gos_duration += self.get_slide_duration(gos_id, slide_id)
            return gos_duration

        # There is a record so the duration is the duration of the record.
        start_time = events[0]['time']
        end_time = events[-1]['time']
        return (end_time - start_time) / 1000.0

    def compose_audio(self) -> str:
        """Mixes the audio.

        Returns:
            str: Stream specifier.

        Mixes all the audio streams in `self.audio_specs`.

        """
        if len(self.audio_specs) == 1:
            return self.audio_specs[0]

        mix_filter = f"amix=inputs={len(self.audio_specs)}"
        output_spec = self.add_filter(self.audio_specs, mix_filter)
        return output_spec

    def compose_slide(self,
                      gos_id: int,
                      slide_id: int,
                      ) -> str:
        """Composes the slide.

        Args:
            gos_id (int): GOS index.
            slide_id (int): Slide index.

        Returns:
            str: Stream specifier.

        `-loop 1 -t {duration} -i {slide_path}` is added to `self.inputs`.
        The necessary filters are added to `self.filters`.
        Only the video stream is returned and needs to be used in the next filter.

        """
        gos_structure = self.structure[gos_id]
        slide = gos_structure['slides'][slide_id]
        slide_uuid = slide['uuid']
        slide_path = os.path.join(self.assets_path, f"{slide_uuid}.webp")
        slide_duration = self.get_slide_duration(gos_id, slide_id)

        # Add the slide.
        self.inputs.append(f"-loop 1 -t {slide_duration} -i {slide_path}")
        output_spec = f"[{len(self.inputs) - 1}:v]"

        # Fix SAR.
        setsar_filter = f"setsar=sar=1"
        output_spec = self.add_filter(output_spec, setsar_filter)

        if slide['extra'] is None:
            return output_spec

        # Add the extra.
        extra_spec = self.compose_extra(gos_id, slide_id)
        overlay_filter = f"overlay=0:0"
        output_spec = self.add_filter(
            [output_spec, extra_spec], overlay_filter)

        return output_spec

    def compose_extra(self,
                      gos_id: int,
                      slide_id: int,
                      ) -> str:
        """Composes the extra.

        Args:
            gos_id (int): GOS index.
            slide_id (int): Slide index.

        Returns:
            str: Stream specifier.

        First paused frames are extracted from the extra video.
        Then the extra video path is added to `self.inputs` with the `-i` option ahead.
        If needed, the extra video stream is split into as much streams as `play` events.
        The paused frames are added to `self.inputs` with the duration option.
        The necessary filters are added to `self.filters`.
        Only the video stream is returned and needs to be used in the next filter.

        """
        gos_structure = self.structure[gos_id]
        slide = gos_structure['slides'][slide_id]
        record = gos_structure['record']

        extra_uuid = slide['extra']
        extra_path = os.path.join(self.assets_path, f"{extra_uuid}.mp4")

        if record is None:
            # If no record, return the extra.
            self.inputs.append(f"-i {extra_path}")
            extra_spec = f"[{len(self.inputs) - 1}:v]"

            # Add the audio.
            extra_spec_a = f"[{len(self.inputs) - 1}:a]"
            extra_delay = self.get_slide_delay(gos_id, slide_id)
            extra_spec_a = self.audio_filter(extra_spec_a, delay=extra_delay)
            self.audio_specs.append(extra_spec_a)
            return extra_spec

        events_stream = []

        # Get the events.
        extra_events = self.get_extra_events(gos_id, slide_id)
        end_time = self.get_slide_delay(gos_id, slide_id + 1)
        extra_events.append({'ty': 'pause', 'time': int(1000.0 * end_time)})
        events_type_start_duration_time = [(event1['ty'],
                                            round(
                                                event1['extra_time'] / 1000.0, 3),
                                            round(
                                                (event2['time'] - event1['time']) / 1000.0, 3),
                                            event1['time'] / 1000.0)
                                           for event1, event2 in zip(extra_events[:-1],
                                                                     extra_events[1:])]

        paused_frames = self.extract_paused_frames(gos_id, slide_id)

        # Get the number of played events.
        nb_played = sum(1 for event_type, _, _,
                        _ in events_type_start_duration_time if event_type == 'play')

        # Add the extra video.
        if nb_played > 0:
            self.inputs.append(f"-i {extra_path}")
            extra_spec = f"[{len(self.inputs) - 1}:v]"
            extra_spec_a = f"[{len(self.inputs) - 1}:a]"

        if nb_played > 1:
            # Split the video.
            split_filter = f"split={nb_played}"
            splited_specs = self.add_filter(
                extra_spec, split_filter, nb_played)

            # Split the audio.
            split_filter_a = f"asplit={nb_played}"
            splited_specs_a = self.add_filter(
                extra_spec_a, split_filter_a, nb_played)
        elif nb_played == 1:
            splited_specs = [extra_spec]
            splited_specs_a = [extra_spec_a]

        for event_type, start, duration, time in events_type_start_duration_time:
            if event_type == 'play':
                # Get the first of remaining splits and trim.
                event_spec = splited_specs.pop(0)
                extra_spec_a = splited_specs_a.pop(0)

                # Trim the extra video.
                trim_filter = f"trim=start={start}:duration={duration},setpts=PTS-STARTPTS"
                event_stream = self.add_filter(event_spec, trim_filter)
                events_stream.append(event_stream)

                # Add the audio.
                extra_spec_a = self.audio_filter(
                    extra_spec_a, start=start, duration=duration, delay=time)
                self.audio_specs.append(extra_spec_a)

            elif event_type == 'pause':
                # Add the paused frame.
                frame_path = paused_frames.pop(0)
                self.inputs.append(f"-loop 1 -t {duration} -i {frame_path}")
                events_stream.append(f"[{len(self.inputs) - 1}:v]")

            else:
                raise RuntimeError(f"Unknown event type: {event_type}")

        # Concatenate the events.
        if len(events_stream) > 1:
            concat_filter = f"concat=n={len(events_stream)}"
            output_spec = self.add_filter(events_stream, concat_filter)
            return output_spec

        return events_stream[0]

    def get_slide_delay(self,
                        gos_id: int,
                        slide_id: int,
                        ) -> float:
        """Get the time to wait before the slide.

        Args:
            gos_id (int): GOS index.
            slide_id (int): Slide index.

        Returns:
            float: The time to wait before the slide. (in seconds)

        The delay is the time since the begeinning of the GOS until the slide.

        """
        return sum(self.get_slide_duration(gos_id, i) for i in range(slide_id))

    def extract_paused_frames(self,
                              gos_id: int,
                              slide_id: int,
                              ) -> List[str]:
        """Extracts the paused frames.

        Args:
            gos_id (int): GOS index.
            slide_id (int): Slide index.

        Returns:
            List[str]: Paused frames paths.

        The paused frames are extracted from the extra video.

        """
        gos_structure = self.structure[gos_id]
        slide = gos_structure['slides'][slide_id]

        # Get the extra path.
        if slide['extra'] is None:
            raise RuntimeError(
                "Error extracting paused frames: There is no extra.")
        extra_uuid = slide['extra']
        extra_path = os.path.join(self.assets_path, f"{extra_uuid}.mp4")

        # Get the paused events.
        extra_events = self.get_extra_events(gos_id, slide_id)
        paused_events = [
            event for event in extra_events if event['ty'] == 'pause']

        frames_paths = []
        for event in paused_events:
            # Extract the frame.
            frame_time = round(event['extra_time'] / 1000.0, 3)
            frame_path = new_tmp_path(dir=self.tmp_path, suffix='.webp')
            cmd = f"ffmpeg -loglevel error -y -ss {frame_time} -i {extra_path} -vframes 1 {frame_path}"
            print(cmd, file=sys.stderr)
            p = subprocess.run(cmd, shell=True)

            if p.returncode != 0:
                raise RuntimeError("Error extracting paused frames.")

            # Add the path to the lists.
            frames_paths.append(frame_path)
            self.tmp_files.append(frame_path)

        return frames_paths

    def compose_record(self,
                       gos_id: int,
                       ) -> str:
        """Composes the record.

        Args:
            gos_id (int): GOS index.

        Returns:
            str: Stream specifier. `None` if there is no video.

        Record path is added to `self.inputs` with the `-i` option ahead.
        The necessary filters are added to `self.filters`.
        Only the video stream is returned and needs to be used in the next filter.

        """
        gos_structure = self.structure[gos_id]
        record = gos_structure['record']
        webcam_settings = gos_structure['webcam_settings']

        if record is None:
            raise RuntimeError(
                f"Error composing record of GOS {gos_id} of capsule {self.capsule_id}: There is no record.")

        # Add the record to the inputs.
        record_uuid = record['uuid']
        record_path = os.path.join(self.assets_path, f"{record_uuid}.webm")
        self.inputs.append(f"-i {record_path}")

        # Add the audio.
        record_spec_a = f"[{len(self.inputs) - 1}:a]"
        self.audio_specs.append(record_spec_a)

        # Early return if no video.
        if (record['size'] is None
                or webcam_settings['type'] == 'disabled'):
            return

        # Video stream.
        output_spec = f"[{len(self.inputs) - 1}:v]"

        # Compute the overlay values.
        if webcam_settings['type'] == 'pip':
            # Overlay size.
            overlay_width = webcam_settings['size'][0]

        elif webcam_settings['type'] == 'fullscreen':
            # Overlay size.
            record_width, record_height = record['size']
            slide_ratio = SLIDE_WIDTH / SLIDE_HEIGHT
            record_ratio = record_width / record_height
            if record_ratio > slide_ratio:
                # Record is wider than the slide.
                overlay_width = SLIDE_WIDTH
            else:
                # Record is taller than the slide.
                overlay_width = int(SLIDE_HEIGHT * record_ratio)

        else:
            raise RuntimeError(
                f"Error composing record of GOS {gos_id} of capsule {self.capsule_id}: Unknown webcam type {webcam_settings['type']}.")

        # Scale the record.
        scale_filter = f"scale={overlay_width}:-1"
        output_spec = self.add_filter(output_spec, scale_filter)

        # Set the opacity.
        opacity = round(webcam_settings['opacity'], 3)
        if opacity < 1:
            opacity_filter = f"format=rgba,colorchannelmixer=aa={opacity}"
            output_spec = self.add_filter(output_spec, opacity_filter)

        return output_spec

    def get_extra_events(self,
                         gos_id: int,
                         slide_id: int,
                         ) -> list:
        """Get the events of the slide for an extra video.

        Args:
            gos_id (int): GOS index.
            slide_id (int): Slide index.

        Returns:
            list: Slide events.

        While recording the extra video, it should be added a `pause` or `play` event when the slide begins.

        When seeking, when the video freezes, it should be added a `pause` event.
        When the video unfreezes, it should be added a `play` or `pause` event.

        """

        # Get the GOS events.
        gos_structure = self.structure[gos_id]
        events = gos_structure['events']
        events = events[1:-1]  # Remove `start` and `end` events.

        # Split the events by slide.
        splited_events = spliter(events, lambda x: x['ty'] == 'next_slide')
        slide_events = splited_events[slide_id]
        slide_events = [
            event for event in slide_events if event['ty'] in ('pause', 'play')]

        return slide_events

    def get_record_position(self,
                            gos_id: int,
                            ) -> Tuple[int, int]:
        """Returns the position of the record.

        Args:
            gos_id (int): GOS index.

        Returns:
            Tuple[int, int]: Position of the record.
        """
        gos_structure = self.structure[gos_id]
        record = gos_structure['record']
        webcam_settings = gos_structure['webcam_settings']
        if webcam_settings['type'] == 'pip':
            # Overlay size.
            overlay_width = webcam_settings['size'][0]

            # Overlay position.
            record_width = record['size'][0]
            size_ratio = overlay_width / record_width

            overlay_x = webcam_settings['position'][0]
            overlay_y = webcam_settings['position'][1]
            if webcam_settings['anchor'] == 'top_right':
                # Invert x-axis.
                overlay_x = SLIDE_WIDTH - \
                    record['size'][0]*size_ratio - overlay_x
            elif webcam_settings['anchor'] == 'bottom_left':
                # Invert y-axis.
                overlay_y = SLIDE_HEIGHT - \
                    record['size'][1]*size_ratio - overlay_y
            elif webcam_settings['anchor'] == 'bottom_right':
                # Invert x-axis.
                overlay_x = SLIDE_WIDTH - \
                    record['size'][0]*size_ratio - overlay_x
                # Invert y-axis.
                overlay_y = SLIDE_HEIGHT - \
                    record['size'][1]*size_ratio - overlay_y

        elif webcam_settings['type'] == 'fullscreen':
            # Overlay size.
            record_width, record_height = record['size']
            slide_ratio = SLIDE_WIDTH / SLIDE_HEIGHT
            record_ratio = record_width / record_height
            if record_ratio > slide_ratio:
                # Record is wider than the slide.
                overlay_width = SLIDE_WIDTH
                overlay_height = int(SLIDE_WIDTH / record_ratio)
            else:
                # Record is taller than the slide.
                overlay_width = int(SLIDE_HEIGHT * record_ratio)
                overlay_height = SLIDE_HEIGHT

            # Overlay position.
            overlay_x = (SLIDE_WIDTH - overlay_width) // 2
            overlay_y = (SLIDE_HEIGHT - overlay_height) // 2

        else:
            raise RuntimeError(
                f"Error composing record of GOS {gos_id} of capsule {self.capsule_id}: Unknown webcam type {webcam_settings['type']}.")

        return int(overlay_x), int(overlay_y)

    def audio_filter(self,
                     audio_spec: str,
                     start: float = None,
                     end: float = None,
                     duration: float = None,
                     delay: float = None,
                     ) -> str:
        """Create an audio filter.

        Args:
            audio_spec (str): The audio spec.
            start_time (float, optional): Audio start time. (in seconds)
            end_time (float, optional): Audio end time. (in seconds)
            duration (float, optional): Audio duration. (in seconds)
            delay (float, optional): Audio delay. (in seconds)

        Returns:
            str: The audio spec.
        """
        # Trim the audio.
        trim_filters = []
        if start is not None:
            trim_filters.append(f"start={start}")
        if end is not None:
            trim_filters.append(f"end={end}")
        if duration is not None:
            trim_filters.append(f"duration={duration}")
        if len(trim_filters) > 0:
            trim_filter = f"atrim={':'.join(trim_filters)}"
            audio_spec = self.add_filter(audio_spec, trim_filter)

        # Add the delay.
        if delay is not None and delay != 0:
            delay_filter = f"adelay=delays={int(1000*delay)}:all=1"
            audio_spec = self.add_filter(audio_spec, delay_filter)

        return audio_spec

    def get_slide_duration(self,
                           gos_id: int,
                           slide_id: int,
                           ) -> float:
        """Get the slide duration. (in seconds)

        Args:
            gos_id (int): GOS index.
            slide_id (int): Slide index.

        Returns:
            float: Slide duration. (in seconds)
        """
        gos_structure = self.structure[gos_id]
        slide = gos_structure['slides'][slide_id]
        events = gos_structure['events']
        record = gos_structure['record']

        if record is None:
            # No record.
            if slide['extra'] is None:
                # No record and no extra.
                return NO_RECORD_SLIDE_DURATION

            # No record and extra.
            extra_uuid = slide['extra']
            extra_path = os.path.join(self.data_path, str(
                self.capsule_id), 'assets', f"{extra_uuid}.mp4")
            return get_duration(extra_path)

        # Find slide starting event.
        step_events = [event for event in events if event['ty']
                       in ('start', 'next_slide', 'end')]
        start_event = step_events[slide_id]
        end_event = step_events[slide_id + 1]

        return (end_event['time'] - start_event['time']) / 1000.0


if __name__ == '__main__':
    raise RuntimeError("This script is not meant to be run directly.")
