"""The release workflow's version check (.github/release-version.sh) and the workflow's shape.
The workflow itself cannot be run here; the script can, so its rules are tested."""
import os
import re
import subprocess

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, ".github", "release-version.sh")
WORKFLOW = os.path.join(ROOT, ".github", "workflows", "release.yml")
FOLDERS = ["FantasyGlassUI", "FantasyGlassUI_Options", "FantasyGlassUI_Locales", "FantasyGlassUI_Planner", "FantasyGlassUI_Gold"]


def make_tree(tmp_path, version):
    for f in FOLDERS:
        d = tmp_path / f
        d.mkdir()
        (d / (f + ".toc")).write_text("## Interface: 50500\n## Title: x\n## Version: %s\n" % version)
    (tmp_path / "FantasyGlassUI" / "Core.lua").write_text('local _, ns = ...\nns.version = "%s"\n' % version)
    return tmp_path


def run(kind, tmp_path):
    p = subprocess.run(["bash", SCRIPT, kind, str(tmp_path)], capture_output=True, text=True)
    return p.returncode, (p.stdout + p.stderr).strip()


def test_release_version_accepts_a_release(tmp_path):
    for v in ("12.4.1", "13.0.0", "13.5.0"):
        d = tmp_path / v
        d.mkdir()
        code, out = run("release", make_tree(d, v))
        assert (code, out) == (0, v)


def test_release_version_refuses_a_beta(tmp_path):
    code, out = run("release", make_tree(tmp_path, "13.5.0-beta.1"))
    assert code == 1 and "not a release version: 13.5.0-beta.1" in out


def test_beta_version_accepts_a_beta(tmp_path):
    code, out = run("beta", make_tree(tmp_path, "13.5.0-beta.1"))
    assert (code, out) == (0, "13.5.0-beta.1")


@pytest.mark.parametrize("v", ["13.5.0", "13.5.0-beta", "13.5.0-rc.1"])
def test_beta_version_refuses(tmp_path, v):
    code, out = run("beta", make_tree(tmp_path, v))
    assert code == 1 and "not a beta version: " + v in out


def test_every_file_must_agree(tmp_path):
    make_tree(tmp_path, "13.5.0-beta.1")
    toc = tmp_path / "FantasyGlassUI_Planner" / "FantasyGlassUI_Planner.toc"
    toc.write_text(toc.read_text().replace("beta.1", "beta.2"))
    code, out = run("beta", tmp_path)
    assert code == 1 and "FantasyGlassUI_Planner/FantasyGlassUI_Planner.toc does not say 13.5.0-beta.1" in out
    make_tree_dir = tmp_path / "again"
    make_tree_dir.mkdir()
    make_tree(make_tree_dir, "13.5.0-beta.1")
    (make_tree_dir / "FantasyGlassUI" / "Core.lua").write_text('ns.version = "13.5.0-beta.2"\n')
    code, out = run("beta", make_tree_dir)
    assert code == 1 and "Core.lua does not say 13.5.0-beta.1" in out


def test_crlf_toc_is_read(tmp_path):
    make_tree(tmp_path, "13.5.0")
    toc = tmp_path / "FantasyGlassUI" / "FantasyGlassUI.toc"
    toc.write_bytes(toc.read_bytes().replace(b"\n", b"\r\n"))
    assert run("release", tmp_path) == (0, "13.5.0")


def test_a_bad_kind_is_refused(tmp_path):
    code, _ = run("nightly", make_tree(tmp_path, "13.5.0"))
    assert code != 0


def workflow():
    return open(WORKFLOW, encoding="utf-8").read()


def test_workflow_beta_trigger():
    w = workflow()
    assert '"beta/**"' in w
    job_if = re.search(r"^    if: (.*)$", w, re.M).group(1)
    assert "'[beta]'" in job_if
    tag_step = w[w.index("- name: Tag the version"):w.index("- name: Build and upload")]
    assert "release-version.sh" in tag_step
    assert "a commit cannot say both [release] and [beta]" in w
    assert 'bash "$RUNNER_TEMP/release.sh" -n "Fantasy Glass UI {project-version}:FantasyGlassUI-{project-version}"' in w
    assert os.access(SCRIPT, os.X_OK)


def test_release_path_unchanged():
    w = workflow()
    job_if = re.search(r"^    if: (.*)$", w, re.M).group(1)
    assert "github.ref == 'refs/heads/main' && contains(github.event.head_commit.message, '[release]')" in job_if
    assert "github.event_name != 'push' || startsWith(github.ref, 'refs/tags/')" in job_if
    assert "already released: raise the version before releasing again" in w
    assert 'git tag -a "$version" -m "$version"' in w
