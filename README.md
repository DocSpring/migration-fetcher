# Migration fetcher
This script will take a DocSpring migration file and download it's parts into your specified directory.

## Dependencies

- [jq](https://jqlang.github.io/jq/)
- gzip/tar
- wget

## How to use
first clone the repo
```sh
git clone https://github.com/docspring/migration-fetcher
cd migration-fetcher
chmod +x migfetch.sh
```

This script relies on jq to parse the JSON index file. Make sure you have it installed first on a mac you can do this with homebrew:

```sh
brew install jq
```

Then run the command using the migration index file as the first argument and the desired download destination in the next.

```sh
./migfetch.sh account_migration_index_mig_XXXXXXXXXXXXXXXXXX.json.gz /path/to/destination
```

## Notes on use

You must ensure that the `mig_XXXXXXXXXXXXXXXXXX` is included in the filename of the index file you pass the script as this is used to build the working directory. You can pass either a `.json.gz` file or a `.json` file and the script will handle either.

When running the script you can choose to either download and extract the files then cleanup the archive files, only download archives without extracting or extract and don't cleanup the archive files. 

If you run the script on the same migration to the same destination the script will detect a previous working directory and prompt if you want to clear it. As this is a destructive action you will have to actively opt into this option or the script will exit.

Each archive comes with an index.json file that outlines what is contained in the file. These are stored in a `indicies` folder within the working directory. 

We have made a best effort to provide timestamped log output to the supplied destination directory in the file `account-migration.log. This logging is additive and will not overwrite your previous runs.

Suggestions and PRs to improve the functionality of this script are welcome.
