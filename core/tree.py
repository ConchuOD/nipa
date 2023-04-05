# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Netronome Systems, Inc.

""" The git tree module """

import os
import tempfile
from typing import List

import core
import core.cmd as CMD
import core.series as SERIES
from core import Patch


# TODO: add patch and CmdError as init here
class PatchApplyError(Exception):
    pass


class PullError(Exception):
    pass


class TreeNotClean(Exception):
    pass


class Tree:
    """The git tree class

    Git tree class which controls a git tree
    """
    def __init__(self, name, pfx, fspath, remote=None, branch=None):
        self.name = name
        self.pfx = pfx
        self.path = os.path.abspath(fspath)
        self.remote = remote
        self.branch = branch

        if remote and not branch:
            self.branch = remote + "/master"

        self._saved_path = None

        self._check_tree()

    def git(self, args: List[str]):
        return CMD.cmd_run(["git"] + args, cwd=self.path)

    def git_am(self, patch):
        return self.git(["am", "-s", "--", patch])

    def git_pull(self, pull_url):
        cmd = ["pull", "--no-edit", "--signoff"]
        cmd += pull_url.split()
        return self.git(cmd)

    def git_status(self, untracked=None, short=False):
        cmd = ["status"]
        if short:
            cmd += ["-s"]
        if untracked is not None:
            cmd += ["-u", untracked]
        return self.git(cmd)

    def git_merge_base(self, c1, c2, is_ancestor=False):
        cmd = ["merge-base", c1, c2]
        if is_ancestor:
            cmd += ['--is-ancestor']
        return self.git(cmd)

    def git_fetch(self, remote):
        return self.git(['fetch', remote])

    def git_reset(self, target, hard=False):
        cmd = ['reset', target]
        if hard:
            cmd += ['--hard']
        return self.git(cmd)

    def git_find_patch(self, needle, depth=1000):
        cmd = [
            "log", "--pretty=format:'%h'", f"HEAD~{depth}..HEAD", f"--grep={needle}",
            "--fixed-strings"
        ]
        return self.git(cmd)

    def _check_tree(self):
        core.log_open_sec("Checking tree " + self.name)
        try:
            out = self.git_status(untracked="no", short=True)
            if out:
                raise TreeNotClean(f"Tree {self.name} is not clean")
        finally:
            core.log_end_sec()

    def reset(self, fetch=None):
        core.log_open_sec("Reset tree " + self.name)
        try:
            if fetch or (fetch is None and self.remote):
                self.git_fetch(self.remote)
            self.git_reset(self.branch, hard=True)
        finally:
            core.log_end_sec()

    def contains(self, commit):
        core.log_open_sec("Checking for commit " + commit)
        try:
            self.git_merge_base(commit, 'HEAD', is_ancestor=True)
            ret = True
        except CMD.CmdError:
            ret = False
        finally:
            core.log_end_sec()

        return ret

    def _find_patch(self, patch):
        out = self.git_find_patch(patch.title)
        return out

    def is_applied(self, thing):
        ret = True

        if isinstance(thing, Patch):
            ret &= bool(self._find_patch(thing))
        elif hasattr(thing, "patches"):
            for patch in thing.patches:
                ret &= bool(self._find_patch(patch))

        return ret

    def check_already_applied(self, thing):
        core.log_open_sec("Checking if applied " + thing.title)
        try:
            self.reset()
            ret = self.is_applied(thing)
        finally:
            core.log_end_sec()

        return ret

    def _apply_patch_safe(self, patch):
        try:
            with tempfile.NamedTemporaryFile() as fp:
                patch.write_out(fp)
                core.log_open_sec("Applying patch " + patch.title)
                try:
                    self.git_am(fp.name)
                finally:
                    core.log_end_sec()
        except CMD.CmdError as e:
            try:
                self.git(["am", "--abort"])
            except CMD.CmdError:
                pass
            raise PatchApplyError(e) from e

    def apply_prereqs(self, prereqs):
        for link in prereqs:
            command = ["b4", "shazam", link]
            try:
                CMD.cmd_run(command, cwd=self.path)
            except CMD.CmdError as e:
                try:
                    self.git(["am", "--abort"])
                except CMD.CmdError:
                    pass
                raise PatchApplyError(e) from e

    def apply(self, thing):
        if isinstance(thing, Patch):
            self._apply_patch_safe(thing)
        elif hasattr(thing, "patches"):
            for patch in thing.patches:
                self._apply_patch_safe(patch)
        else:
            raise Exception("Can't apply object '%s' to the git tree" % (type(thing), ))

    def check_applies(self, thing):
        core.log_open_sec("Test-applying " + thing.title)
        try:
            self.reset()
            self.apply(thing)
            ret = True
        except PatchApplyError:
            ret = False
        finally:
            core.log_end_sec()

        return ret

    def check_applies_with_depends(self, thing):
        core.log_open_sec("Test-applying (with pre-reqs) " + thing.title)
        try:
            self.reset()

            if hasattr(thing, "cover_letter"):
                core.log_open_sec(thing.title + " has a cover, checking pre-reqs")
                depends = thing.depends_from_cover()
                if depends:
                    core.log_open_sec("Applying pre-reqs for " + thing.title)
                    self.apply_prereqs(depends)

            self.apply(thing)
            ret = True
        except PatchApplyError:
            ret = False
        finally:
            core.log_end_sec()

        return ret

    def _pull_safe(self, pull_url):
        try:
            self.git_pull(pull_url)
        except CMD.CmdError as e:
            try:
                self.git(["merge", "--abort"])
            except CMD.CmdError:
                pass
            raise PullError(e) from e

    def pull(self, pull_url):
        core.log_open_sec("Pulling " + pull_url)
        try:
            self.reset()
            self._pull_safe(pull_url)
        finally:
            core.log_end_sec()

    def get_current_head(self):
        ret = "n/a"
        try:
            self.reset()
            ret = self.git(["rev-parse", "--short", "HEAD"])
        except CMD.CmdError:
            pass

        return ret
