# lyricify.nvim

Show the lyrics of the song Spotify playing inside your best editor ever! For fun of course :)

**NOTE: if you're not a Chinese speaker, be cautious to use this plugin.**

![](https://github.com/v1nh1shungry/lyricify.nvim/assets/98312435/df063fb4-5b44-4467-8773-b91d11085e9b)

![](https://github.com/v1nh1shungry/lyricify.nvim/assets/98312435/46753827-a8a9-41f0-bd2c-6dd355df63c8)

## Table of Contents

<!-- markdown-toc -->
* [Requirements](#requirements)
* [Installation](#installation)
* [Configuration](#configuration)
* [Usage](#usage)
* [How to do](#how-to-do)
<!-- markdown-toc -->

## Requirements

* Spotify
* [spicetify](https://github.com/spicetify/cli)
* Node.js
* Neovim >= 0.10

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "v1nh1shungry/lyricify.nvim",
    opts = {},
}
```

Then you should go to the plugin directory, copy the script `lyricify-nvim.js` to the
extensions directory of spicetify. Run:

```bash
spicetify config extensions lyricify-nvim.js
spicetify apply
```

## Configuration

**NOTE: you should always call `setup()` before you use the plugin.**

```lua
-- default
{
  update_interval = 500, -- ms
  min_width = 40,
  max_width = 120,
  -- used to customize where the popup shows
  -- `width` and `height` will be the width and height of the popup
  position = function(width, height)
    return 1, math.floor((vim.o.columns - width) / 2)
  end,
}
```

## Usage

* `show()`: show the lyric popup
* `hide()`: hide the lyric popup
* `toggle()`: toggle the lyric popup

## How to do

If you happen to be a Chinese speaker, you can go check my blog post 👉 [在 Neovim 中显示 Spotify 歌词](https://zhuanlan.zhihu.com/p/701959617)
