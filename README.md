# clementcolin.com

My portfolio website, self-hosted at home in Tokyo on a second-hand school
Chromebook (Acer Spin 511 R752T, Celeron, 4GB RAM) running Linux Mint, bought
at Hard Off for ¥5,000.

A Chromebook cannot normally boot anything but ChromeOS. Its stock firmware
was replaced with [MrChromebox](https://mrchromebox.tech/) full UEFI firmware
(coreboot + edk2), which turns a locked-down school machine into an ordinary
x86 computer that boots standard Linux.

The site itself is static HTML and CSS. No framework and no build step. The
one piece of JavaScript is the playable SDL Raycaster demo under
`site/demos/`, the C engine compiled to WebAssembly with Emscripten and
served as static files like everything else. The site is served by nginx
running in Docker and exposed to the internet through a Cloudflare Tunnel, so
the home router keeps zero open ports and the home IP never appears in DNS.

## Architecture

```
            Internet
               │
               ▼
     ┌───────────────────┐
     │  Cloudflare edge  │  DNS + TLS for clementcolin.com
     └─────────┬─────────┘
               │  tunnel (outbound-only connection,
               │  established from inside the LAN)
   ────────────┼────────────────────────  home router: zero open ports
               ▼
     ┌───────────────────┐     docker network      ┌───────────────┐
     │    cloudflared    │ ──────────────────────► │  nginx:alpine │
     │     container     │      http://web:80      │   container   │
     └───────────────────┘                         └───────┬───────┘
                                                           │ read-only mount
                                                     ./site (static files)

           Acer Chromebook R752T · Linux Mint · docker compose
```

## How it works

A visitor resolves clementcolin.com to Cloudflare's edge, which terminates
TLS. Cloudflare forwards the request through a tunnel that the `cloudflared`
container opened from inside my LAN, so no inbound connection ever reaches the
router. `cloudflared` hands the request to the nginx container over the
private Docker network, and nginx serves the static files from a read-only
mount of `site/`.

Consequences of this design:

- No port forwarding, no dynamic DNS, no exposed home IP.
- TLS certificates live at the Cloudflare edge, nothing to renew on the box.
- The only secret is the tunnel token, kept in a gitignored `.env` file.
  `.env.example` documents the expected shape.
- Deploying a site update is `git pull` on the server. The `site/` directory
  is mounted into nginx, so there is nothing to rebuild or restart.
- The Chromebook's battery doubles as a small UPS.

## Stack

| Layer | Choice |
|---|---|
| Hardware | Acer Chromebook Spin 511 (R752T), fanless |
| Firmware | [MrChromebox](https://mrchromebox.tech/) UEFI (coreboot + edk2) |
| OS | Linux Mint |
| Runtime | Docker + docker compose |
| Web server | nginx (alpine image) |
| Ingress | cloudflared (Cloudflare Tunnel, free plan) |
| DNS + TLS | Cloudflare edge |
| Site | Static HTML/CSS, plus one WebAssembly demo (Emscripten) |

## Roadmap

- [x] README, architecture
- [ ] docker compose stack (nginx + cloudflared)
- [ ] nginx configuration
- [ ] the site itself
- [ ] test on a Linux Mint VM
- [ ] Cloudflare account, DNS migration, tunnel creation
- [ ] deploy on the Chromebook
