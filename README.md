# DevboxLauncher

Start devboxes quickly

## Installation

- Install the gem: `gem install devbox_launcher`
- Setup `gcloud init` with the project that contains your VM
- Install [mutagen](https://mutagen.io)

## Usage

`gcloud auth list` should already have the account/s setup. If not, login via `gcloud auth login`.

Create the config file at `~/.devbox_launcher.yml` so you type less. This is an example of a personal and work configuration:

```yml
ramon@email.com:
  - box: your-instance-name
    project: general-192303
    zone: us-central1-a
    mutagen:
      alpha: /mnt/c/Users/me/src # local machine
      beta: ~/src # remote machine
ramon@company.com:
  project: development-254604
  box: ramon
```

To start and create the mutagen session:

```sh
devbox start your-username
```

- Want to ssh in immediately?
  - Add `--ssh` switch
- Want to mosh in immediately?
  - Add `--mosh` switch. Mosh needs to be [installed](https://mosh.org/) in your development machine.
- More than one box with the same Google Cloud account?
  - Pass in the box in your command, via `devbox start user@domain.com/box-name`
  - No need to configure `box:` in the YAML file

Note: Linux users that sync mutagen sessions need to install [Watchman](https://facebook.github.io/watchman/).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/devbox_launcher. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the DevboxLauncher project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/devbox_launcher/blob/master/CODE_OF_CONDUCT.md).
