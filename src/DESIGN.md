# OneCord Installer Design

Dark-only UI inspired by [amber-minimal](https://21st.dev/community/themes/amber-minimal)

## Tokens

| Token | Hex | Usage |
| ----- | --- | ----- |
| background | `#171717` | Form body |
| card | `#262626` | Rounded cards |
| track | `#141414` | Segment control inset |
| sidebar gradient | `#0c0c0c` to `#161411` | Header |
| accent gradient | `#d97706` to `#fbbf24` | Header rule, primary buttons |
| foreground | `#ffffff` | Titles |
| muted | `#a3a3a3` | Field labels |
| subtle | `#737373` | Helper text |
| primary | `#f59e0b` | Selected segment |
| destructive | `#ef4444` | Remove outline |

## Layout

Coordinates live in `installer/UiLayout.cs`. Form is **500 x 640** client pixels and does not resize

| Region | Y | Height |
| ------ | - | ------ |
| Header | dock top | 92 |
| Accent rule | dock top | 2 |
| Protocol card | 0 | 118 |
| Proxy card | 134 | 252 |
| Action buttons | 402 | 40 |
| About link | 458 | 20 |
