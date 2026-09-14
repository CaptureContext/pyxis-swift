#!/usr/bin/env python3
"""Calculate a release tag without modifying Git or publishing anything."""

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import subprocess


NUMBER = r"(0|[1-9][0-9]*)"
TAG = re.compile(rf"{NUMBER}\.{NUMBER}\.{NUMBER}")


@dataclass(frozen=True, order=True)
class Version:
    major: int
    minor: int
    patch: int

    @classmethod
    def parse(cls, tag):
        match = TAG.fullmatch(tag)
        if match is None:
            return None
        return cls(*(int(value) for value in match.groups()))

    def __str__(self):
        return f"{self.major}.{self.minor}.{self.patch}"

    def bump(self, bump):
        if bump == "major":
            return Version(self.major + 1, 0, 0)
        if bump == "minor":
            return Version(self.major, self.minor + 1, 0)
        if bump == "patch":
            return Version(self.major, self.minor, self.patch + 1)
        raise ValueError(f"Unsupported bump: {bump}")


def next_release(tags, bump):
    versions = [version for tag in tags if (version := Version.parse(tag)) is not None]
    previous = max(versions) if versions else Version(0, 0, 0)
    return previous, previous.bump(bump)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bump", choices=("major", "minor", "patch"), required=True)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    tags = subprocess.check_output(["git", "tag", "--list"], text=True).splitlines()
    previous, version = next_release(tags, args.bump)
    if args.github_output:
        with args.github_output.open("a") as output:
            output.write(f"previous_tag={previous}\ntag={version}\n")
    print(f"{previous} -> {version}")


if __name__ == "__main__":
    main()
