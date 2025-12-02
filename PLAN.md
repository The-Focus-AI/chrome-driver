# Setup the project

> /project-setup:setup-beads

Quit claude

## Research

> run the tech research agent to understand how to interact with the chrome dev tools using only standard installed perl

This starts and goes for about 7 minutes.  But in the meantime, in another Claude:

> use the research agent to learn how to build claude code skills that we can package up into a plugin 

## Spec

> I want to build a claude skill that makes it very easy for an LLM to interact with a remote site.  It sshould be smart enough to automatically start up a chrome instance if needed, it should be able to navigate to different pages, extract content from it as text or markdown, take a screenshot, record a video of it interacting, and print the page as a pdf.  The tool should explain itself to the LLM, and be composed of small tools that the model can put together.  Please ask me clarifying questions about this one at a time, then write a SPEC.md file that documents the requirements, and the plan out the step by step implementation

It goes through and asks me a bunch of questions and then `Now I have everything I need. Let me write the SPEC.md.`/

It writes out the IMPLEMENTATION.md, and then starts firing up beads to track everything.


```markdown
Done! Here's what I've created:

  Summary

  Documents Created

  | File              | Purpose                                   |
  |-------------------|-------------------------------------------|
  | SPEC.md           | Full requirements specification           |
  | IMPLEMENTATION.md | 13-phase step-by-step implementation plan |

  Key Decisions Captured

  - Pure Perl with standard modules only (Perl 5.14+)
  - Auto-start/auto-stop Chrome lifecycle
  - Both HTML and Markdown content extraction
  - Composable primitives - screenshot, screencast frames, etc.
  - Full PDF options exposed
  - All auth mechanisms - cookies, profiles, form filling
  - All JS layers - high-level helpers, injection, raw CDP
  - Optional network module for advanced use
  - Interactive help system
  - Full plugin with skills, slash commands, hooks
  - macOS + Linux + WSL support

  Beads Tracking

  14 issues created | 4 ready | 10 blocked (waiting on dependencies)

  Ready to start:
  1. chrome-driver-ug8 - Phase 1: WebSocket & CDP Core (priority 1, start here)
  2. chrome-driver-cfo - Epic tracking
  3. chrome-driver-3uk - Phase 11: Help System (can be done in parallel)
  4. chrome-driver-a5s - Phase 10: Network (optional, can start anytime)

  Critical path: Phase 1 → Phase 2 → Phase 3 → (Phases 4-9 in parallel) → Phase 12 → Phase 13

  Would you like to start implementing Phase 1 (WebSocket & CDP Communication Core)?
```

## Start a new claude

To keep everything fresh, lets start up a new claude, and

```bash
claude --dangerously-skip-permissions
```

And then:

> do the most important thing

And off it goes:


## Appendix: Results CDP

```markdown
The research is complete. Here's the summary:

  Chrome DevTools Protocol with Standard Perl

  Good news: CDP can be fully implemented using only core Perl modules (no CPAN needed).

  Required Modules (all standard since Perl 5.14)

  | Module           | Purpose                        |
  |------------------|--------------------------------|
  | IO::Socket::INET | TCP sockets for WebSocket      |
  | HTTP::Tiny       | HTTP requests to /json/version |
  | JSON::PP         | JSON encode/decode             |
  | Digest::SHA      | SHA-1 for WebSocket handshake  |
  | MIME::Base64     | Base64 encoding                |

  How It Works

  1. Launch Chrome: google-chrome --remote-debugging-port=9222
  2. HTTP Discovery: GET http://localhost:9222/json/version to find WebSocket URL
  3. WebSocket Handshake: Manual RFC 6455 implementation (~100-150 lines)
  4. CDP Commands: JSON-RPC over WebSocket frames

  The Tricky Part

  WebSocket frames require manual encoding:
  - Client frames MUST be masked (XOR with 4-byte random key)
  - Server frames are NOT masked
  - Text frames use opcode 0x01

  Alternative: Shell Out

  If manual WebSocket is too complex, use websocat:
  use IPC::Open2;
  my $pid = open2(my $from_ws, my $to_ws, "websocat", $ws_url);

  Caveats

  - No wss:// (SSL) without CPAN modules - but localhost:9222 uses plain ws://
  - Requires Perl 5.14+ (standard on modern macOS/Linux)

  The full report with working code examples is at:
  reports/2025-12-02-perl-chrome-devtools-protocol.md
```

## Appendix: Results Plan Skills

```markdown
The research is complete. Here's a comprehensive summary:

  Claude Code Skills & Plugins

  Skills vs Slash Commands

  | Type           | Invocation                  | Definition             |
  |----------------|-----------------------------|------------------------|
  | Skills         | Claude decides autonomously | skills/<name>/SKILL.md |
  | Slash Commands | User types /command         | commands/<name>.md     |

  Plugin Directory Structure

  my-plugin/
  ├── .claude-plugin/
  │   └── plugin.json          # Required manifest
  ├── skills/
  │   └── my-skill/
  │       └── SKILL.md         # Skill definition
  ├── commands/
  │   └── my-command.md        # Slash commands
  ├── agents/
  │   └── my-agent.md          # Custom subagents
  └── hooks/
      └── hooks.json           # Event handlers

  SKILL.md Format

  ---
  name: code-analyzer
  description: Analyze code quality. Use when user asks for code review or bug detection.
  allowed-tools: Read, Glob, Grep
  ---

  # Code Analyzer

  ## Instructions
  [What to do when skill is activated]

  ## Examples
  [Usage examples for Claude to understand scope]

  plugin.json (Required)

  {
    "name": "my-plugin",
    "version": "1.0.0",
    "description": "What this plugin does",
    "author": "Your Name"
  }

  Distribution

  1. Create marketplace repo with .claude-plugin/marketplace.json:
  {
    "name": "my-marketplace",
    "plugins": [{"name": "my-plugin", "source": "https://github.com/..."}]
  }
  2. Users install:
  /plugin marketplace add yourname/marketplace-repo
  /plugin install my-plugin@my-marketplace

  Key Tips for Skill Activation

  - Include explicit trigger phrases in description
  - Be specific: "Use when user asks for X, Y, or Z"
  - Keep skills focused on one capability
  - Include comprehensive examples

  Resources

  - https://github.com/anthropics/skills
  - https://github.com/jeremylongshore/claude-code-plugins-plus (185+ examples)
  - https://github.com/obra/superpowers

  Want me to create a skeleton plugin structure for this project?
```


# YOLO

```bash
claude -p "Do the next most important thing" --verbose --dangerously-skip-permissions  --output-format stream-json
```