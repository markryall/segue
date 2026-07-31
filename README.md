# Segue

A crossfading queueing daemon for [mpv](https://mpv.io) - kind of like `mpd` but nowhere near as flexible or
useful.

A *segue* is the radio and DJ term for a transition where one track fades into the next, which is the whole
point of this thing.

The player daemon starts two instances of mpv and uses those to play any tracks placed in the queue.

Why two instances? mpv doesn't support crossfading between tracks, so this crossfades by starting the other
mpv instance playing the next track and adjusting the volume of both.

This is a rewrite of [vlcraptor](https://github.com/markryall/vlcraptor), which did the same thing with two
copies of the VLC desktop app. mpv is a better fit: it's a headless binary rather than a `.app` bundle, it
speaks JSON over a unix socket instead of a line oriented telnet interface, and it runs anywhere rather than
only where VLC happens to be installed in `/Applications`.

## Installation

`brew install mpv` (or your platform's equivalent) - segue looks for `mpv` on your `PATH`.

`brew install ffmpeg` is required by the `queue` command for extracting tags to place in the queue.

`brew install terminal-notifier` is optional depending on whether you want notifications when new tracks
start.

This gem can be installed with `gem install segue`.

## Usage

Running `segue` without any parameters will list the available subcommands.

### Player

Run `segue player` in a shell session.

This is the player daemon that controls two instances of mpv. It is an ncurses application which will take
over the display in that terminal.

You can quit with 'q', pause with ' ', stop with 's', play (resume) with 'p' and skip with 'n'.

### Adding tracks to the queue

`segue queue folder_containing_audio_files audio_file.mp3` will place any number of audio files in the queue
and the player should immediately start playing the first track.

### Viewing queue contents

`segue list` will list currently queued tracks with an estimated start time if the player is currently running
and playing a track.

### Managing queue

`segue clear` will clear all queued tracks.

`segue remove 2` will remove the queued track at index position 2.

`segue swap 2 4` will swap the tracks at index positions 2 and 4.

### Media controls

`segue pause` will pause, `segue stop` will stop and `segue play` will resume.

`segue skip` will fade out the current track and start the next one (unless the queue is empty).

### Optional features

A number of features can be turned on/off while the player is running that will determine certain behaviour:

`segue autoplay off` will cause the player to stop and politely wait after the current track has finished.
`segue autoplay on` and tracks will start playing again.

`segue crossfade off` will turn off crossfading so new tracks will start once the previous one is completely
finished.

`segue scrobble on` will turn on last.fm scrobbling - you will require your own application api key and secret
to enable this.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `SEGUE_HOME` | `~/.segue` | Where preferences, history and the queue are kept |
| `SEGUE_MPV` | `mpv` | The mpv executable to launch |

Keeping all state under one directory means segue can be run alongside vlcraptor (or a second copy of itself,
with a different `SEGUE_HOME`) without the two fighting over the same queue.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

The mpv IPC client is covered by specs that talk to a fake mpv over a unix socket, so the test suite does not
require mpv to be installed.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update
the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for
the version, push git commits and the created tag, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/markryall/segue.
