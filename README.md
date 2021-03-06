# Gum

Gum is a handy Git repository summarizer, with additional "active" features planned for later.
Typical current use case is to keep up to date with new commits in various Git repositories of interest in the form of one daily email with a summary.

Please note that push times are not recorded in Git, so simple approaches for keeping track of updates such as `git log -p --since="1 day ago"` do not work because they refer to commit times; commits may have happened days or weeks ago before they were pushed to the monitored repositories, so they would slip through this kind of a filter.

To solve that, Gum creates local branches which track branches updated from the remote repositories. Then, the challenge of finding all commits added since the last check comes down to comparing two on-disk branches.

## Installation

Obtain Gum:

```sh
git clone https://github.com/crystallabs/gum
```

For convenience, statically-compiled and ready to use versions of Gum can be found in bin/gum.* within the repository. Please use the ones appropriate for your machine architecture. To compile Gum yourself, obtain the Crystal programming language from https://crystal-lang.org/docs/installation/, and then run:

```
shards
make release
```

Finally, copy the resulting `bin/gum.*` to a location of choice, such as `/usr/local/bin`.

## Usage

```
gum -h
```

Gum by default uses a config file found in `$HOME/.config/gum/gumrc` and watches the "master" branch of all Git repositories found in `$HOME/gum/`.

So, to start monitoring repositories, simply clone them inside `$HOME/gum/`. For example:

```
cd ~/gum
git clone https://github.com/crystallabs/gum
```

Then, simply run `gum` to see a report on the changes since the last run. To update the changes locally so that they would not appear again on the next invocation of `gum`, run `gum -l`.

Since there will be no changes to any repositories when you first install and try Gum, you could then do a test commit yourself and run Gum again. Here's an example for doing it on our existing clone of Gum's repository itself that was demonstrated in the previous example.

```
cd ~/gum/gum
git checkout master
touch test
git add test
git commit test -m "Test commit"
gum
```

(Then just make sure to delete this whole repository and start clean, because you do not want these test commits remaining in there.)

To run gum once a day, you would typically add a cron entry such as:

```
0 0 * * * /usr/local/bin/gum -s warn -l | mail -s "Gum Report for `date +%F`" your@email
```

Option "-s warn" will reduce log output by ignoring all logs with severity below "warning", and option "-l" will update the local repositories after showing the diffs so that the same diffs are not displayed again on the next invocation.

## Configuration

When Gum is started, if a config file does not exist, it is automatically created. A config file looks like the following:

```
basedir: /home/user/gum
repositories: {}
prefix: gum_local-
logfile: STDOUT
loglevel: debug
update_remote: true
update_local: false
show_remote_pulls: true
show_local_pulls: false
show_diffs: true
write_config: false
```

With the meaning of options being as follows:

* basedir: Base directory with cloned repositories. All repositories must be cloned under this directory with no intermediate subdirectories. The directory names are unrelated to the locations they are cloned from, so you can easily avoid any unlikely naming conflicts by cloning to different directory names or mv-ing directories to different names.
* repositories: Contains a list of repositories and their branches to monitor. If this list is empty, all repositories found in `basedir` are monitored on their `master` branch.
* prefix: Gum implements showing diffs on the basis of comparing two branches. For every branch tracked, a "local" branch is created, named "$prefix$branch_name". With prefix "gum_local-", branches named "master" would be tracked in local branches named "gum_local-master".
* logfile: Logging-related option. File names STDOUT and STDERR refer to existing filehandles, while any other value is taken as file name.
* loglevel: Logging-related option. Log level (severity) should be one of: debug, info, warn, error, fatal, unknown.
* update_remote: Update remote branches before running and showing differences?
* update_local: Update local branches after running and showing differences?
* show_remote_pulls: Include the output of `git pull` in remote branches in the total output? Using this provides a nice additional summary of the scope and size of changes made.
* show_local_pulls: Include the output of `git pull` in local branches in the total output?
* show_diffs: Show the actual diffs between previous and current state? This should be enabled most of the time, unless you specifically want to update remote and/or local branches without caring about seeing any diffs.
* write_config: Write config to the config file after parsing all options? This should usually be disabled, but it is a great way to convert a set of command line options into defaults saved to a config file, or to produce the initial YAML content that can then be manually modified. Please note that if this option is used, config file is saved with the list of repositories specifically listed, so any new repositories cloned inside `basedir` will not immediately start being monitored. You will have to update the list manually, or empty it to enable tracking of all repositories found in `basedir`.
