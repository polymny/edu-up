import subprocess
import os
import re
import sys

from utils import *
from vars import *


def pdf2webp(
    input: str,
    output: str,
    size: str = '1920x1080',
    density: int = 380,
    colorspace: str = 'sRGB',
    background: str = 'white',
    gravity: str = 'center'
) -> None:
    """Convert a pdf to a webp.

    Args:
        input (str): Path to the input pdf.
        output (str): Path to the output webp.
        size (str, optional): Dimension of the webp. Defaults to '1920x1080'.
        density (int, optional): Density of pdf sampling. Defaults to 380.
        colorspace (str, optional): Alternate image colorspace. Defaults to 'sRGB'.
        background (str, optional): The color to fill the background with. Defaults to 'white'.
        gravity (str, optional): Horizontal and vertical placement. Defaults to 'center'.
    """

    # Run the command.
    cmd = f"convert \
            -density {density} \
            -colorspace {colorspace} \
            -resize {size} \
            -background {background} \
            -gravity {gravity} \
            -extent {size} \
            {input} {output}"
    p = subprocess.run(cmd, shell=True, capture_output=True)
    if p.returncode != 0:
        raise Exception(f"Error converting pdf to webp: {p.stderr.decode()}")

    return


def record(
    capsule_id: int,
    record_uuid: str,
) -> str:
    """Save a record.

    Args:
        capsule_id (int): The capsule id.
        record_uuid (str): The record's uuid.

    Returns:
        str: The size of the record (WxH) or "" if the record is an audio file.

    The record is reencoded to make sure everything is fine.
    The first frame is saved as a thumbnail.
    """
    data_path = get_config(keys=('default', 'data_path'))
    capsule_path = os.path.join(data_path, str(capsule_id))
    record_path = os.path.join(capsule_path, "assets", f"{record_uuid}.webm")

    # Reeencode the video.
    tmp_path = new_tmp_path(suffix='.webm')
    cmd = f"ffmpeg -hide_banner -loglevel error -nostats -y -i {record_path} -c copy -fflags +genpts {tmp_path}"
    p = subprocess.run(cmd, shell=True, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(f"Failed to reencode {record_path}.\n{p.stderr.decode()}")
    subprocess.run(f"mv {tmp_path} {record_path}", shell=True)

    # Check if the video has a video stream.
    cmd = f"ffprobe -hide_banner -loglevel error -show_streams \
          -select_streams v -of 'compact' {record_path}"
    p = subprocess.run(cmd, shell=True, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(f"Failed to get the type of {record_path}.\n{p.stderr.decode()}")
    has_video_stream = p.stdout.decode() != ""

    if has_video_stream:
        thumbnail_path = os.path.join(capsule_path, "assets", f"{record_uuid}.webp")
        cmd = f"ffmpeg -nostats -loglevel error -hide_banner -y \
                -i {record_path} \
                -ss 0.0 \
                -vframes 1 \
                {thumbnail_path}"
        p = subprocess.run(cmd, shell=True, capture_output=True)
        if p.returncode != 0:
            raise RuntimeError(f"Failed to extract the thumbnail of {record_path}.\n{p.stderr.decode()}")

        # Get the width and height.
        width, height = get_width_height(record_path)
        return f"{width}x{height}"

    return ""


def audio(
    input: str,
    output: str,
) -> None:
    """Transcode an audio file.

    Args:
        input (str): Path to the input audio file.
        output (str): Path to the output audio file.
    """

    duration = get_duration(input)

    # Run the command.
    cmd = f"ffmpeg -nostdin -nostats -progress pipe:1 -loglevel error -hide_banner -y \
          -i {input} -vn -c:a {ACODEC} -b:a {ABITRATE} -ar {ARATE} {output}"
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    # Get the progress.
    while True:
        line = p.stdout.readline()
        if not line:
            break
        matcher = re.search(r"out_time_ms=(\d+)", line.decode())
        if matcher:
            progress = float(matcher.group(1)) / duration / 1e6
            sys.stdout.write(f"{progress:.2f}\n")
            sys.stdout.flush()

    p.wait()
    if p.returncode != 0:
        raise RuntimeError(f"Failed to transcode {input}.\n{p.stderr.read()}")
    return


def video(
    input: str,
    output: str,
) -> None:
    """Transcode a video file.

    Args:
        input (str): Path to the input video file.
        output (str): Path to the output video file.
    """

    duration = get_duration(input)

    # Check if the video has an audio stream.
    cmd = f"ffprobe -hide_banner -loglevel error -show_streams \
          -select_streams a -of 'compact' {input}"
    p = subprocess.run(cmd, shell=True, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(f"Failed to get the type of {input}.\n{p.stderr.decode()}")
    has_audio_stream = p.stdout.decode() != ""

    # Add a silent audio stream if there is no audio stream.
    silent_audio = f"-f lavfi -i anullsrc=channel_layout=stereo:sample_rate={ARATE}"
    if has_audio_stream:
        silent_audio = ""

    # Run the command.
    cmd = f"ffmpeg -nostdin -nostats -progress pipe:1 -loglevel error -hide_banner -y \
            -i {input} \
            {silent_audio} \
            -filter:v \
                'scale={SLIDE_WIDTH}:{SLIDE_HEIGHT}:force_original_aspect_ratio=decrease, \
                 pad={SLIDE_WIDTH}:{SLIDE_HEIGHT}:-1:-1:color=black, \
                 setsar=1:1,fps=fps={FRAME_RATE}' \
            -vsync cfr \
            -pix_fmt {PIXEL_FORMAT} \
            -vcodec {VCODEC} \
            -crf 15 \
            -acodec {ACODEC} \
            -ar {ARATE} \
            -ac 2 \
            -b:a {ABITRATE} \
            -max_muxing_queue_size 2048 \
            {output}"
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    # Get the progress.
    while True:
        line = p.stdout.readline()
        if not line:
            break
        matcher = re.search(r"out_time_ms=(\d+)", line.decode())
        if matcher:
            progress = float(matcher.group(1)) / duration / 1e6
            sys.stdout.write(f"{progress:.2f}\n")
            sys.stdout.flush()

    p.wait()
    if p.returncode != 0:
        raise RuntimeError(f"Failed to transcode {input}.\n{p.stderr.read()}")
    return


if __name__ == '__main__':
    raise RuntimeError('This script is not meant to be run directly.')
