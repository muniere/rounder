# Rounder

Fetch latest releases with Elixir (http://elixir-lang.org/)

## Requirements

- [Elixir](http://elixir-lang.org/) >= 1.1.0
- [Rake](https://github.com/ruby/rake) >= 10.4.0

## Installation

```bash
# clone
$ git clone git@tighub.com:muniere/rounder.git

# install
$ cd rounder
$ ./configure --prefix=/usr/local
$ rake && rake install

# or only link
$ rake && rake link
```

## Usage

### Check releases

```bash
# check last releases
$ rounder bitwalker/timex edgurgel/httpoison

# sort by date (desc)
$ rounder --sort=date bitwalker/timex edgurgel/httpoison

# sort by tag (asc)
$ rounder --sort=tag bitwalker/timex edgurgel/httpoison

# read repositories list from file
$ cat repos.txt
bitwalker/timex
edgurgel/httpoison

$ rounder -i repos.txt
```
