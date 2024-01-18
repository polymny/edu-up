import typing
import subprocess
import tempfile
import os
import json
import toml
import sys


def spliter(obj: typing.Iterable,
            key: typing.Callable,
            ) -> list[list[typing.Any]]:
    """Split an iterable into a list of lists.

    Args:
        obj (typing.Iterable): The iterable to split.
        key (typing.Callable): The key to split on.

    Returns:
        list[list[typing.Any]]: The list of lists.

    The iterable is split on the elements for which the key returns True.
    The elements for which the key returns True are not included in the result.

    """
    result = []
    current = []
    for item in obj:
        if key(item):
            result.append(current)
            current = []
        else:
            current.append(item)
    result.append(current)

    return result


def get_duration(file_path: str):
    """Get the duration of a video/audio file.

    Args:
        file_path (str): Path to the video/audio file.

    Returns:
        float: The duration of the video/audio file (in seconds).

    If the file is corrupted, it will be regenerated and the duration will be
    computed again. If the file is still corrupted, an exception will be raised.

    """
    cmd = f"ffprobe -v error -show_entries format=duration -of compact=nokey=1:print_section=0 {file_path}"
    result = subprocess.run(cmd, shell=True, capture_output=True)

    if result.returncode != 0:
        # Command failed, regenerate the file and try again.
        file_extension = file_path.split(".")[-1]
        tmp_file = new_tmp_path(suffix=f".{file_extension}")
        cmd = f"ffmpeg -loglevel error -y -i {file_path} -c copy {tmp_file}"
        p = subprocess.run(cmd, shell=True, capture_output=True)
        if p.returncode != 0:
            raise RuntimeError(f"Failed to regenerate {file_path}.\n{p.stderr.decode()}")

        # Get the duration.
        cmd = f"ffprobe -v error -show_entries format=duration -of compact=nokey=1:print_section=0 {tmp_file}"
        result = subprocess.run(cmd, shell=True, capture_output=True)
        if result.returncode != 0:
            raise RuntimeError(f"Could not get the duration of {file_path}.\n{result.stderr.decode()}")
        os.remove(tmp_file)

    return float(result.stdout)


def get_width_height(file_path: str) -> tuple[int, int]:
    """Get the width and height of a video file.

    Args:
        file_path (str): Path to the video file.

    Returns:
        tuple[int, int]: The width and height of the video file.
    """
    # Get the width and height.
    cmd = f"ffprobe -v error -select_streams v:0 -show_entries stream=width,height,sample_aspect_ratio,display_aspect_ratio -of json=c=1 {file_path}"
    p = subprocess.run(cmd, shell=True, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(f"Failed to get the width and height of {file_path}.\n{p.stderr.decode()}")
    result = p.stdout.decode()

    # Parse the result.
    result = json.loads(result)
    width = int(result["streams"][0]["width"])
    height = int(result["streams"][0]["height"])

    return width, height


def add_soundtrack(video_path: str,
                   soundtrack_path: str,
                   output_path: str,
                   soundtrack_volume: float = 1.0,
                   fade_duration: float = 1.0,
                   ) -> None:
    """Adds a soundtrack to a video.

    Args:
        video_path (str): The video path.
        soundtrack_path (str): The soundtrack path.
        output_path (str): The output path.
        soundtrack_volume (float, optional): Volume of the soundtrack. Defaults to 1.0.
        fade_duration (float, optional): Duration of the fade in and out. Defaults to 1.0.

    The soundtrack is faded in and out at the beginning and the end of the video.
    If the video is longer than the soundtrack, the soundtrack is repeated.
    Between each repetition, the soundtrack is faded out and in.

    """
    # Get the duration of the video and the soundtrack.
    capsule_duration = get_duration(video_path)
    soundtrack_duration = get_duration(soundtrack_path)

    # Prepare the fade filter.
    fadeout_start = soundtrack_duration - fade_duration
    fade_filter = f"afade=t=in:st=0:d={fade_duration},afade=t=out:st={fadeout_start}:d={fade_duration}"

    # Prepare the filter inputs and outputs.
    nb_fades = int(capsule_duration / soundtrack_duration) + 1
    fade_filter_inputs = ""
    fade_filter_outputs = ""
    for i in range(0, nb_fades):
        fade_filter_inputs += f"[1:a]{fade_filter}[fade{i}];"
        fade_filter_outputs += f"[fade{i}]"

    # Add the soundtrack.
    fadeout_start = capsule_duration - fade_duration
    cmd = f"ffmpeg -y -loglevel error -i \
            {video_path} -i {soundtrack_path} \
            -filter_complex \
            \"{fade_filter_inputs} \
            {fade_filter_outputs} concat=n={nb_fades}:v=0:a=1[concat]; \
            [concat]volume={soundtrack_volume}[volume]; \
            [volume]afade=t=out:st={fadeout_start}:d={fade_duration}[fade]; \
            [0:a][fade]amerge=inputs=2[out]\" \
            -map 0:v \
            -map [out] \
            -c:v copy \
            -c:a aac \
            -shortest \
            {output_path}"

    p = subprocess.run(cmd, shell=True)
    if p.returncode != 0:
        raise RuntimeError(f"Failed to add soundtrack to video.")


def concat_videos(input_paths: list[str],
                  output_path: str,
                  ) -> None:
    """Concatenates videos.

    Args:
        input_files (list[str]): Input files.
        output_file (str): Output file.

    All videos should have the same resolution and framerate.
    Otherwise, I don't know what will happen. ‾\_(°.°)_/‾

    """
    # Create the input file list.
    input_file_list = tempfile.NamedTemporaryFile(mode='w', delete=False)
    for input_file in input_paths:
        input_file_list.write(f"file '{input_file}'\n")
    input_file_list.close()

    # Concatenate the video clips.
    cmd = f"ffmpeg -nostats -loglevel error -hide_banner -y \
                -f concat \
                -safe 0 \
                -i {input_file_list.name} \
                -c copy \
                -movflags +faststart \
                {output_path}"
    p = subprocess.run(cmd, shell=True)

    # Remove the input file list.
    os.remove(input_file_list.name)

    # Check the return code.
    if p.returncode != 0:
        raise RuntimeError(f"Failed to concatenate video clips.")


def new_tmp_path(dir: str = None, suffix: str = None) -> str:
    """Returns a temporary file path.

    Args:
        dir (str, optional): The directory of the temporary file.
        suffix (str, optional): The suffix of the temporary file.

    Returns:
        str: The temporary file path.
    """
    tmp_file = tempfile.NamedTemporaryFile(dir=dir, suffix=suffix)
    tmp_file.close()
    return tmp_file.name


def format_time(time: int) -> str:
    """Format a time in seconds to a string.

    Args:
        time (int): The time in milliseconds.

    Returns:
        str: The formatted time.
    """
    millis = int(time % 1000)
    total_seconds = int(time // 1000)
    seconds = int(total_seconds % 60)
    minutes = int((total_seconds // 60) % 60)
    hours = int(total_seconds // 3600)
    formatted_time = f"{hours:02d}:{minutes:02d}:{seconds:02d}.{millis:03d}"
    return formatted_time


def get_config(config_file: str = "Rocket.toml",
               keys: tuple[str] = (),
               ) -> typing.Any:
    """Get a value from the config file.

    Args:
        config_file (str, optional): The path to the config file. Defaults to "Rocket.toml".
        keys (tuple[str], optional): The successive keys to access the value. Defaults to ().

    Returns:
        typing.Any: The value.
    """
    with open(config_file) as f:
        config = toml.load(f)
        for key in keys:
            config = config[key]
        return config


if __name__ == '__main__':
    raise RuntimeError('This script is not meant to be run directly.')
