# Launch posts

Outlines and fact sheets for the first announcement. Nothing has been posted. Every fact below is backed by the
README, `docs/how-it-works.md`, the changelog of 0.1.0 or a linked source; do not add numbers, users or
compatibility that the repository does not show.

**Read this first.** This kit was written with an AI assistant, and the project's commits carry an AI co-author.
Several venues care about both, so these are outlines to post **in your own words**, not text to paste.

Placeholders: `[MOTIVATION]` is why you built it, in your words. `[AI USE]` is an honest sentence on how AI tools were
used (code, docs, these posts). `[REPO]` is `https://github.com/maximeallanic/window-magnet` once it is public.

## Before posting

- Publish v0.1.0. Its checksum is already pinned in `install.sh`: tag `v0.1.0` on `main` and push the tag; the
  release workflow rebuilds the zip, checks it against the pin and publishes it (`scripts/release.sh` header). Until then the one-line install fails, and every
  post must give the `git clone` + `./install.sh --from-source` path instead.
- Install from the public repository on a second machine or a fresh user, and run `verify.sh`.
- Upload `docs/marketing/social-preview.png` as the repository's social preview and fill in the About box from
  [github-metadata.md](github-metadata.md).
- Decide on extensions.gnome.org first if you can: This Week in GNOME only covers extensions published there, and
  many GNOME users install only from there.
- One venue a day, and stay around for the comments.

## Venue rules (checked 2026-10-20)

| Venue | Rule, quoted from the source | What to do |
|---|---|---|
| Hacker News, Show HN | [Guidelines](https://news.ycombinator.com/newsguidelines.html): "Don't post generated text or AI-edited text." and "Don't solicit upvotes, comments, or submissions." [Show HN](https://news.ycombinator.com/showhn.html): "Show HN is for something you've made that other people can play with.", "The project must be something you've worked on personally and which you're around to discuss.", "Don't post quickly-generated one-offs; anybody can do that now.", "Please don't ask friends to upvote or comment." | Title below as is; **write the first comment yourself** from the fact sheet. Post only once the one-line install works, so people can try it |
| r/gnome | Rules could not be read from here (Reddit refuses automated requests). GNOME Discourse says it copied r/gnome's policy (below), so expect the same: posts written entirely by an LLM and projects written entirely by an LLM are removed | Read the sidebar before posting; write the post yourself; disclose AI use |
| GNOME Discourse | [Emmanuele Bassi, 2026-07-01](https://discourse.gnome.org/t/llm-generated-projects-and-content-on-gnomes-discourse-instance/36006): the site adopts "the same policy for LLM generated projects and content as the r/gnome subreddit"; moderators remove "topics that are written entirely via LLM" and topics announcing projects "that are entirely written by an LLM" | Same as r/gnome. If most of the code came from an AI, expect removal: decide before posting |
| This Week in GNOME | [About](https://thisweek.gnome.org/about/): "Your update must be relevant to GNOME or related projects (e.g. Flatpak)."; "The project should be published on an established platform so that users can access it via regular sources" (extensions.gnome.org for extensions); "Don't use an LLM to generate your message." Notes go to TWIG-Bot in the `#thisweek:gnome.org` Matrix room | **Only after extensions.gnome.org accepts it.** Short note, your words |
| extensions.gnome.org | [Review guidelines](https://gjs.guide/extensions/review-guidelines/review-guidelines.html): "While it is not prohibited to use AI as a learning aid or a development tool (i.e. code completions), extension developers should be able to justify and explain the code they submit, within reason." and "Submissions with large amounts of unnecessary code, inconsistent code style, imaginary API usage, comments serving as LLM prompts, or other indications of AI-generated output will be rejected." | Not a post, but it decides whether "coming to extensions.gnome.org" can be promised. The drafts do not promise it. Be ready to explain every file, in particular the resize timing in `extension.js` and `dropPlacer.js` |
| r/linux | Not readable from here either. Reddit's general norm: take part in the community, do not only post your own links | Read the sidebar first; same disclosure |
| Mastodon / Fediverse | No network-wide rule; each instance has its own. Hashtags make posts findable | CamelCase hashtags for screen readers; alt text on the GIF |

## Fact sheet (for every venue)

Use these as raw material. Each line is checked against the repository or a linked source.

- **What it is**: a GNOME Shell 51 extension, MIT, version 0.1.0. While you move or resize a window with the pointer
  or touch, its edges snap to the edges of the other windows on the same workspace and monitor, and to the screen's
  work area (below the top bar, beside docks). Snap distance 16 px by default, 4 to 64.
- **The history it answers**: GNOME 40's Mutter made window-edge snapping Ctrl-only (Mutter NEWS, 40.alpha: "Only
  snap to window edges when CTRL is pressed"), after reports that drags stuttered, e.g.
  [Ubuntu bug 1727225](https://bugs.launchpad.net/ubuntu/+source/gnome-shell/+bug/1727225) (2017): "Gnome Shell
  seems to do excessive window snapping while dragging windows." In Mutter 51, a plain drag still resists at screen
  and monitor edges; Ctrl adds other windows' edges; Shift makes it snap (`src/compositor/meta-window-drag.c`).
- **The spring**: the window's real position snaps at once; its on-screen actor is offset by the opposite of the jump
  and a spring brings the offset back to zero. Spring = Material 3 Expressive "FastSpatial" from the owner's motion
  toolkit (vendored from m3e-gnome-extensions), whose solver is a port of Jetpack Compose's. Follows GNOME's
  *Reduce Animation* setting.
- **Holds, then lets go**: Mutter recomputes the raw position from the pointer at every motion, so a snap holds the
  window until the pointer has moved past the threshold; nothing extra is needed for "unsnap".
- **Only facing edges**: another window only counts on one axis when it overlaps the moved window on the other axis.
- **Resize without flicker** (the hard part): Mutter computes the raw size in a `BEFORE_REDRAW` later on the stage's
  `before-update` signal; the extension connects to the same signal after Mutter, so the snapped size goes out in
  the same frame and the Wayland client only applies the last configure. Correcting on `size-changed` made the
  window alternate between two sizes. `Meta.ExternalConstraint` would be the clean API but cannot be used from GJS.
- **Dropped tabs**: on Wayland an app cannot place its own windows. The extension spots Mutter's drag actor
  (`MetaDnDActor`) and the window the same process creates within 500 ms after the drop (measured: 30 to 130 ms),
  requests the size at `window-created` and the position at `shown`. No app is named in the code.
- **Privacy**: no subprocess, no network, no file access.
- **Tests**: headless unit tests (gjs) for the snapping, jump and drop maths; an end-to-end run in a nested GNOME
  Shell 51 that drags real windows and disables the extension in the middle of a drag to check no window stays
  offset. The README GIF was recorded in that nested Shell, at real speed.
- **Limits, say them up front**: GNOME Shell 51 only; not on extensions.gnome.org yet; pointer and touch drags
  only, not keyboard moves; not tested alongside tiling extensions; English and French translations so far; first
  release, not yet tried on many machines.
- **What you want from readers**: reports from other distributions, monitors and apps; translations.

## Show HN

Post only once the one-line install works.

Title (64 characters, limit 80):

> Show HN: Window edges that snap together in GNOME, with a spring

URL: `[REPO]`

First comment: **write it yourself**; HN forbids generated or AI-edited text. A possible order, in your own
sentences:

1. [MOTIVATION]: why you wanted it, what you did before (Ctrl-drag? another desktop?).
2. One line on the GNOME 40 change and why it happened (fact sheet, "history").
3. The two technical points HN readers tend to ask about: the spring on the actor while the real position snaps, and the
   resize timing on `before-update`.
4. The dropped-tab placement, one line.
5. Limits, plainly.
6. [AI USE]: HN readers will ask; say it before they do.

## r/gnome

Title (yours to reword):

> I missed GNOME snapping windows to each other, so I made an extension that does it with a spring (GNOME 51)

Body outline:

- [MOTIVATION], and how the project was made: [AI USE]. r/gnome removes LLM-written posts and LLM-written projects.
- What it does in two lines; attach `media/demo.gif` (or the MP4) so people see the spring.
- Why it does not feel like the old snapping: spring, holds then lets go, facing edges only, a switch per source.
- GNOME-side details: public Shell and Mutter APIs only; nothing created before `enable()`, everything undone in
  `disable()`; follows *Reduce Animation*; GNOME Shell 51 only; not on extensions.gnome.org yet.
- Install line (one-line once released, else clone + `--from-source`); `verify.sh` for "nothing happens".
- Ask: "If you use a tiling extension too, tell me whether they get along."

## GNOME Discourse

Pick the category that fits third-party extensions after browsing the site; same outline and disclosure as r/gnome,
a little more technical (resize timing, dropped tabs). Ask a concrete question rather than "what do you think", e.g.
whether exposing an external constraint to GJS would be welcome upstream.

## r/linux

Title:

> Window Magnet: window edges that snap together on GNOME, with a spring

- [MOTIVATION] in one or two sentences.
- The GNOME 40 change, one line; the comparison with KDE's and Xfce's built-in snap zones, one line: on those
  desktops this is a setting, on GNOME it needs Ctrl or an extension.
- The GIF, install line, limits line, [AI USE].

## This Week in GNOME

Only once extensions.gnome.org has accepted it. A note of two or three short sentences in your own words: what it
does, the extensions.gnome.org link, one screenshot or the GIF. TWIG asks for no LLM-written messages.

## Mastodon

Write it yourself; keep it under 500 characters (a link counts as 23). Ingredients:

- one sentence: window edges snap together on GNOME, with a spring, no key to hold;
- one sentence: pull further and it lets go; resize snaps too; dropped tabs open where you drop them;
- "GNOME Shell 51, MIT, feedback welcome", `[REPO]`;
- hashtags: `#GNOME #Linux #FOSS #OpenSource`;
- `[AI USE]` in the post or a reply if your audience expects it.

Attach `media/demo.gif` with this alt text:

> A window dragged next to two others: its right edge snaps to their left edge, its top aligns with the first one,
> then it is pulled away, snapped to the left edge of the screen and resized until it snaps again.
