import sys
import json
import subprocess
import os

from utils import *
from vars import *


class Publisher:
    """Publisher class."""

    def __init__(self,
                 capsule_id: int,
                 ):
        """Initialize the Publisher class.

        Args:
            capsule_id (int): The capsule id.

        Publisher is first waiting for the capsule info to be sent in the stdin.
        """
        self.capsule_id = capsule_id

        self.structure = json.load(sys.stdin)

        self.data_path = get_config(keys=('default', 'data_path'))
        self.capsule_path = os.path.join(self.data_path, str(self.capsule_id))
        self.assets_path = os.path.join(self.capsule_path, "assets")

    def publish(self,
                input: str,
                output: str,
                use_prompt_subtitles: bool) -> None:
        """Publish the capsule.

        Args:
            input (str): Path to the input file.
            output (str): Path to the output file.
            use_prompt_subtitles (bool): Use the prompt subtitles.
        """
        # If the prompt subtitles are not used, simply run the hls script.
        if not use_prompt_subtitles:
            cmd = f"../hls/hls {input} {output} 360p 480p 720p"
            p = subprocess.run(cmd, shell=True)
            if p.returncode != 0:
                raise RuntimeError(f"Failed to publish {input}.\n{p.stderr.decode()}")
            return

        # The prompt subtitles are used.
        cmd = f"../hls/hls --subtitles subtitles.webvtt {input} {output} 360p 480p 720p"
        p = subprocess.run(cmd, shell=True)
        if p.returncode != 0:
            raise RuntimeError(f"Failed to publish {input}.\n{p.stderr.decode()}")

        # Init webvtt.
        vtt_path = os.path.join(output, "subtitles.webvtt")
        with open(vtt_path, "w") as f:
            f.write("WEBVTT\n")
            f.write("X-TIMESTAMP-MAP=MPEGTS:120000,LOCAL:00:00:00.000\n")
            f.write("\n")

        slide_time = 0
        for i in range(len(self.structure)):
            # Reset counters.
            last_time = 0
            slide_index = 0
            sentence_index = 0

            gos = self.structure[i]

            record = gos['record']
            if record is None:
                # No record, no subtitles to add, just increment timers.
                for slide in gos['slides']:
                    extra = slide['extra']
                    if extra is None:
                        slide_time += NO_RECORD_SLIDE_DURATION * 1000
                    else:
                        extra_path = os.path.join(self.assets_path, f"{extra}.mp4")
                        duration = get_duration(extra_path)
                        slide_time += duration * 1000
            else:
                # Record, add subtitles.
                for event in gos['events']:
                    ty = event['ty']
                    time = event['time']

                    # Skip useless events.
                    if ty in ('start', 'play', 'pause'):
                        continue

                    with open(vtt_path, "a") as f:
                        # Write the time.
                        t1 = format_time(last_time + slide_time)
                        t2 = format_time(time + slide_time)
                        f.write(f"{t1} --> {t2}\n")

                        # Write the sentence.
                        sentence = gos['slides'][slide_index]['prompt'].split("\n")[sentence_index]
                        f.write(f"{sentence}\n")
                        f.write("\n")

                    last_time = time

                    # Increment counters.
                    if ty == 'next_slide':
                        slide_index += 1
                        sentence_index = 0
                    elif ty == 'next_sentence':
                        sentence_index += 1
                    elif ty == 'end':
                        slide_time += time


if __name__ == '__main__':
    raise RuntimeError("This script is not supposed to be executed.")
