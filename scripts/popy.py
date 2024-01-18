#!/usr/bin/env python
import argparse

from rich_argparse import RawDescriptionRichHelpFormatter

from utils import *
from vars import *
import producer
import converter
import publisher


if __name__ == '__main__':
    parser = argparse.ArgumentParser(formatter_class=RawDescriptionRichHelpFormatter,
                                     description="""Popy is a tool for Polymny video production.""")
    parser.set_defaults(run=lambda args: parser.print_help())
    subparser = parser.add_subparsers()

    # Production.
    produce_parser = subparser.add_parser(name='produce',
                                          help='produce a video',
                                          formatter_class=RawDescriptionRichHelpFormatter,
                                          description="""""")
    produce_subparser = produce_parser.add_subparsers()

    # Production: capsule.
    produce_capsule_parser = produce_subparser.add_parser(name='capsule',
                                                          help='produce a capsule',
                                                          formatter_class=RawDescriptionRichHelpFormatter,
                                                          description="""""")

    produce_capsule_parser.add_argument('-c',
                                        '--cid',
                                        type=str,
                                        help='capsule id',
                                        metavar='CAPSULE_ID',
                                        dest='cid',
                                        required=True)
    produce_capsule_parser.set_defaults(run=lambda args:
                                        producer.Producer(int(args.cid)).produce_capsule())

    # Production: GOS.
    produce_gos_parser = produce_subparser.add_parser(name='gos',
                                                      help='produce a GOS',
                                                      formatter_class=RawDescriptionRichHelpFormatter,
                                                      description="""""")
    produce_gos_parser.add_argument('-c',
                                    '--cid',
                                    type=str,
                                    help='capsule id',
                                    metavar='CAPSULE_ID',
                                    dest='cid',
                                    required=True)
    produce_gos_parser.add_argument('-g',
                                    '--gid',
                                    type=str,
                                    help='GOS id',
                                    metavar='GOS_ID',
                                    dest='gid',
                                    required=True)
    produce_gos_parser.set_defaults(run=lambda args:
                                    producer.Producer(int(args.cid)).produce_gos(int(args.gid)))

    # Convert.
    convert_parser = subparser.add_parser(name='convert',
                                          help='convert a file',
                                          formatter_class=RawDescriptionRichHelpFormatter,
                                          description="""""")
    convert_subparser = convert_parser.add_subparsers()

    # Convert: pdf2webp.
    convert_pdf2webp_parser = convert_subparser.add_parser(name='pdf2webp',
                                                           help='convert a pdf to a webp',
                                                           formatter_class=RawDescriptionRichHelpFormatter,
                                                           description="""""")
    convert_pdf2webp_parser.add_argument('-i',
                                         '--input',
                                         type=str,
                                         help='input file',
                                         metavar='INPUT_FILE',
                                         dest='input',
                                         required=True)
    convert_pdf2webp_parser.add_argument('-o',
                                         '--output',
                                         type=str,
                                         help='output file',
                                         metavar='OUTPUT_FILE',
                                         dest='output',
                                         required=True)
    convert_pdf2webp_parser.add_argument('-d',
                                         '--density',
                                         type=int,
                                         help='density',
                                         metavar='DENSITY',
                                         dest='density',
                                         required=True)
    convert_pdf2webp_parser.add_argument('-s',
                                         '--size',
                                         type=str,
                                         help='size',
                                         metavar='SIZE',
                                         dest='size',
                                         required=True)
    convert_pdf2webp_parser.set_defaults(run=lambda args:
                                         converter.pdf2webp(
                                             input=args.input,
                                             output=args.output,
                                             density=args.density,
                                             size=args.size,
                                         ))

    # Convert: record.
    convert_record_parser = convert_subparser.add_parser(name='record',
                                                         help='reencode a record and save a thumbnail',
                                                         formatter_class=RawDescriptionRichHelpFormatter,
                                                         description="""""")
    convert_record_parser.add_argument('-c',
                                       '--cid',
                                       type=int,
                                       help='capsule id',
                                       metavar='CAPSULE_ID',
                                       dest='cid',
                                       required=True)
    convert_record_parser.add_argument('-u',
                                       '--uuid',
                                       type=str,
                                       help='record uuid',
                                       metavar='RECORD_UUID',
                                       dest='uuid',
                                       required=True)
    convert_record_parser.set_defaults(run=lambda args:
                                       print(converter.record(args.cid, args.uuid)))

    # Convert: audio.
    convert_audio_parser = convert_subparser.add_parser(name='audio',
                                                        help='transcode an audio file',
                                                        formatter_class=RawDescriptionRichHelpFormatter,
                                                        description="""""")
    convert_audio_parser.add_argument('-i',
                                      '--input',
                                      type=str,
                                      help='input file',
                                      metavar='INPUT_FILE',
                                      dest='input',
                                      required=True)
    convert_audio_parser.add_argument('-o',
                                      '--output',
                                      type=str,
                                      help='output file',
                                      metavar='OUTPUT_FILE',
                                      dest='output',
                                      required=True)
    convert_audio_parser.set_defaults(run=lambda args:
                                      converter.audio(args.input, args.output))

    # Convert: video.
    convert_video_parser = convert_subparser.add_parser(name='video',
                                                        help='transcode a video file',
                                                        formatter_class=RawDescriptionRichHelpFormatter,
                                                        description="""""")
    convert_video_parser.add_argument('-i',
                                      '--input',
                                      type=str,
                                      help='input file',
                                      metavar='INPUT_FILE',
                                      dest='input',
                                      required=True)
    convert_video_parser.add_argument('-o',
                                      '--output',
                                      type=str,
                                      help='output file',
                                      metavar='OUTPUT_FILE',
                                      dest='output',
                                      required=True)
    convert_video_parser.set_defaults(run=lambda args:
                                      converter.video(args.input, args.output))

    # Publish.
    publish_parser = subparser.add_parser(name='publish',
                                          help='publish a capsule',
                                          formatter_class=RawDescriptionRichHelpFormatter,
                                          description="""""")
    publish_parser.add_argument('-i',
                                '--input',
                                type=str,
                                help='input file',
                                metavar='INPUT_FILE',
                                dest='input',
                                required=True)
    publish_parser.add_argument('-o',
                                '--output',
                                type=str,
                                help='output file',
                                metavar='OUTPUT_FILE',
                                dest='output',
                                required=True)
    publish_parser.add_argument('-c',
                                '--cid',
                                type=int,
                                help='capsule id',
                                metavar='CAPSULE_ID',
                                dest='cid',
                                required=True)
    publish_parser.add_argument('-p',
                                '--prompt',
                                action='store_true',
                                help='use prompt subtitles',
                                dest='prompt',
                                required=False)
    publish_parser.set_defaults(run=lambda args:
                                publisher.Publisher(args.cid).publish(args.input, args.output, args.prompt))

    # Duration.
    duration_parser = subparser.add_parser(name='duration',
                                           help='get the duration of a file',
                                                formatter_class=RawDescriptionRichHelpFormatter,
                                                description="""""")

    duration_parser.add_argument('-f',
                                 '--file',
                                 type=str,
                                 help='file',
                                 metavar='FILE',
                                 dest='file',
                                 required=True)
    duration_parser.set_defaults(run=lambda args:
                                 print(get_duration(args.file)))

    # Parse arguments.
    args = parser.parse_args()
    args.run(args)
