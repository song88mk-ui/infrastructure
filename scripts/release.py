import logging
import re

import click
from github import Auth, Github, GithubException

TAG_RE = re.compile(
    r"^(?P<prefix>v?)(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)-(?P<env>stg|prd)$"
)

logging.getLogger("github").setLevel(logging.CRITICAL)


class GitHub:
    def __init__(self, repo, token):
        self.repo = repo
        self._repo = Github(auth=Auth.Token(token), per_page=100).get_repo(repo)

    def default_branch(self):
        return self._repo.default_branch

    def commit_sha(self, ref):
        return self._repo.get_commit(ref).sha

    def tags(self):
        return {t.name: t.commit.sha for t in self._repo.get_tags()}

    def generate_notes(self, tag, target, previous=None):
        kwargs = {"target_commitish": target}
        if previous:
            kwargs["previous_tag_name"] = previous
        return self._repo.generate_release_notes(tag, **kwargs).body

    def create_release(self, tag, target, notes, prerelease, make_latest):
        return self._repo.create_git_release(
            tag,
            name=tag,
            message=notes,
            prerelease=prerelease,
            target_commitish=target,
            make_latest="true" if make_latest else "false",
        )


class Tag:
    def __init__(self, name, sha, match):
        self.name = name
        self.sha = sha
        self.prefix = match["prefix"]
        self.version = (int(match["major"]), int(match["minor"]), int(match["patch"]))


def tags_for_env(all_tags, env):
    result = []
    for name, sha in all_tags.items():
        match = TAG_RE.match(name)
        if match and match["env"] == env:
            result.append(Tag(name, sha, match))
    return sorted(result, key=lambda t: t.version)


def bump(version, part):
    major, minor, patch = version
    if part == "major":
        return (major + 1, 0, 0)
    if part == "minor":
        return (major, minor + 1, 0)
    return (major, minor, patch + 1)


def format_tag(prefix, version, env):
    return f"{prefix}{version[0]}.{version[1]}.{version[2]}-{env}"


def release(gh, tag, sha, previous, prerelease, make_latest, dry_run):
    notes = gh.generate_notes(tag, sha, previous)
    line = "=" * 72
    click.echo(f"\n{line}")
    click.echo(f"  Repository : {gh.repo}")
    click.echo(f"  New tag    : {tag}")
    click.echo(f"  Commit     : {sha}")
    click.echo(f"  Notes from : {previous or '(beginning of history)'}")
    click.echo(line)
    click.echo(notes.strip() or "(empty)")
    click.echo(line)

    if dry_run:
        click.echo("Dry run: nothing was created.")
        return
    if not click.confirm(f"Create release {tag}?", default=False):
        click.echo("Aborted. Nothing was created.")
        raise SystemExit(1)
    created = gh.create_release(tag, sha, notes, prerelease, make_latest)
    click.echo(f"Created release {tag}: {created.html_url}")


def deploy_to_stage(gh, bump_part, target, initial_version, dry_run):
    target = target or gh.default_branch()
    sha = gh.commit_sha(target)
    click.echo(f"Target: {target} @ {sha[:12]}")

    all_tags = gh.tags()
    stg_tags = tags_for_env(all_tags, "stg")
    if stg_tags:
        latest = stg_tags[-1]
        click.echo(f"Latest -stg tag: {latest.name} @ {latest.sha[:12]}")
        if latest.sha == sha:
            click.echo(f"Warning: {target} has no new commits since {latest.name}.")
        new_tag = format_tag(latest.prefix, bump(latest.version, bump_part), "stg")
        previous = latest.name
    else:
        if not TAG_RE.match(f"{initial_version}-stg"):
            raise click.ClickException(f"Invalid --initial-version: {initial_version}")
        click.echo("No existing -stg tags found; using the initial version.")
        new_tag = f"{initial_version}-stg"
        previous = None

    if new_tag in all_tags:
        raise click.ClickException(f"Tag {new_tag} already exists.")

    release(
        gh, new_tag, sha, previous, prerelease=False, make_latest=False, dry_run=dry_run
    )


def deploy_to_prod(gh, dry_run):
    all_tags = gh.tags()
    stg_tags = tags_for_env(all_tags, "stg")
    if not stg_tags:
        raise click.ClickException("No -stg tags found; nothing to promote.")

    stg = stg_tags[-1]
    prd_name = stg.name.removesuffix("-stg") + "-prd"
    click.echo(f"Latest -stg tag: {stg.name} @ {stg.sha[:12]}")
    if prd_name in all_tags:
        raise click.ClickException(
            f"{prd_name} already exists; {stg.name} was already promoted."
        )

    prd_tags = tags_for_env(all_tags, "prd")
    if prd_tags and prd_tags[-1].version > stg.version:
        click.echo(f"Warning: {prd_tags[-1].name} is newer than {stg.name}.")
    older = [t for t in prd_tags if t.version < stg.version]
    previous = older[-1].name if older else None

    release(
        gh,
        prd_name,
        stg.sha,
        previous,
        prerelease=False,
        make_latest=True,
        dry_run=dry_run,
    )


def validate_repo(ctx, param, value):
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", value):
        raise click.BadParameter("must be in the form <org>/<repo_name>")
    return value


@click.command()
@click.argument("repo", callback=validate_repo)
@click.argument("environment", type=click.Choice(["stage", "prod"]))
@click.option(
    "--token",
    envvar="GITHUB_TOKEN",
    required=True,
    help="GitHub API token (or GITHUB_TOKEN).",
)
@click.option(
    "--bump",
    "bump_part",
    type=click.Choice(["major", "minor", "patch"]),
    default="patch",
    show_default=True,
    help="Semver part to bump (stage).",
)
@click.option(
    "--target",
    help="Branch or commit to tag (stage). Defaults to the default branch.",
)
@click.option(
    "--initial-version",
    default="v0.1.0",
    show_default=True,
    help="Version used when no -stg tag exists.",
)
@click.option("--dry-run", is_flag=True, help="Preview without creating anything.")
def main(repo, environment, token, bump_part, target, initial_version, dry_run):
    try:
        gh = GitHub(repo, token)
        if environment == "stage":
            deploy_to_stage(gh, bump_part, target, initial_version, dry_run)
        else:
            deploy_to_prod(gh, dry_run)
    except GithubException as e:
        message = e.data.get("message") if isinstance(e.data, dict) else e.data
        raise click.ClickException(f"GitHub API error ({e.status}): {message}")


if __name__ == "__main__":
    main()
