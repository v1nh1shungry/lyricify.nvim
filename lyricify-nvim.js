if (!navigator.serviceWorker) {
  let num = null;
  onmessage = event => {
    if (event.data === "lyricify-nvim-request-update") {
      num = setTimeout(() => postMessage("lyricify-nvim-update-ui"), 500);
    } else if (event.data === "lyricify-nvim-stop-request") {
      clearTimeout(num);
    }
  }
} else {
  lyricify();
}

/**
 * @param {string} s
 * @param {boolean} emptySymbol
 */
function normalize(s, emptySymbol = true) {
  const result = s
    .replace(/（/g, "(")
    .replace(/）/g, ")")
    .replace(/【/g, "[")
    .replace(/】/g, "]")
    .replace(/。/g, ". ")
    .replace(/；/g, "; ")
    .replace(/：/g, ": ")
    .replace(/？/g, "? ")
    .replace(/！/g, "! ")
    .replace(/、|，/g, ", ")
    .replace(/‘|’|′|＇/g, "'")
    .replace(/“|”/g, '"')
    .replace(/〜/g, "~")
    .replace(/·|・/g, "•");
  if (emptySymbol) {
    result.replace(/-/g, " ").replace(/\//g, " ");
  }
  return result.replace(/\s+/g, " ").trim();
}

/**
 * @param {string} s
 */
function removeExtraInfo(s) {
  return (
    s
      .replace(/-\s+(feat|with|prod).*/i, "")
      .replace(/(\(|\[)(feat|with|prod)\.?\s+.*(\)|\])$/i, "")
      .replace(/\s-\s.*/, "")
      .trim() || s
  );
}

/**
  * @param {string} s
  */
function capitalize(s) {
  return s.replace(/^(\w)/, $1 => $1.toUpperCase());
}

/**
  * @param {string} lyricStr
  */
function parseLyrics(lyricStr) {
  const otherInfoKeys = [
    "\\s?作?\\s*词|\\s?作?\\s*曲|\\s?编\\s*曲?|\\s?监\\s*制?",
    ".*编写|.*和音|.*和声|.*合声|.*提琴|.*录|.*工程|.*工作室|.*设计|.*剪辑|.*制作|.*发行|.*出品|.*后期|.*混音|.*缩混",
    "原唱|翻唱|题字|文案|海报|古筝|二胡|钢琴|吉他|贝斯|笛子|鼓|弦乐",
    "lrc|publish|vocal|guitar|program|produce|write|mix"
  ];
  const otherInfoRegexp = new RegExp(`^(${otherInfoKeys.join("|")}).*(:|：)`, "i");
  const lines = lyricStr.split(/\r?\n/).map(line => line.trim());
  let noLyrics = false;
  const lyrics = lines
    .flatMap(line => {
      const matchResult = line.match(/(\[.*?\])|([^\[\]]+)/g) || [line];
      if (!matchResult.length || matchResult.length === 1) {
        return {};
      }
      const textIndex = matchResult.findIndex(slice => !slice.endsWith("]"));
      let text = "";
      if (textIndex > -1) {
        text = matchResult.splice(textIndex, 1)[0];
        text = capitalize(normalize(text, false));
      }
      if (text === "纯音乐, 请欣赏") {
        noLyrics = true;
      }
      return matchResult.map(slice => {
        const matchResult = slice.match(/[^\[\]]+/g);
        const [key, value] = (matchResult && matchResult[0].split(":")) || [];
        const [min, sec] = [Number.parseFloat(key), Number.parseFloat(value)];
        if (!Number.isNaN(min) && !Number.isNaN(sec) && !otherInfoRegexp.test(text)) {
          return {
            startTime: min * 60 + sec,
            text: text || "♪♪♪",
          };
        }
        return {};
      });
    })
    .sort((a, b) => {
      if (a.startTime === undefined) {
        return 0;
      }
      if (b.startTime === undefined) {
        return 1;
      }
      return a.startTime - b.startTime;
    })
    .filter(Boolean);
  if (noLyrics) {
    return { error: "纯音乐, 请欣赏" };
  }
  if (!lyrics.length) {
    return { error: "歌词解析失败" };
  }
  return { lyrics };
}

function lyricify() {
  const { Player, CosmosAsync } = Spicetify;

  if (!Player || !CosmosAsync) {
    setTimeout(lyricify, 500);
    return;
  }

  const worker = new Worker("./extensions/lyricify-nvim.js");
  worker.onmessage = event => {
    if (event.data === "lyricify-nvim-update-ui") {
      tick();
    }
  };

  let sharedData = { lyrics: [], tlyrics: [] };

  async function fetchNetease(info) {
    const requestHeader = {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:93.0) Gecko/20100101 Firefox/93.0"
    };
    const title = removeExtraInfo(normalize(info.title));
    const keyword = encodeURIComponent(`${title} ${info.artist}`);
    const searchURL = `http://music.163.com/api/search/get/?s=${keyword}&limit=10&type=1&offset=0`;
    let searchResults;
    try {
      searchResults = await CosmosAsync.get(searchURL, undefined, requestHeader);
    } catch (err) {
      return { error: "网络异常" };
    }
    const items = searchResults.result.songs;
    if (!items || !items.length) {
      return { error: "歌曲消失在茫茫的曲库中了" };
    }
    const itemId = items.findIndex(val => capitalize(val.album.name) === capitalize(info.album) || Math.abs(info.duration - val.duration) < 1000);
    if (itemId === -1) {
      return { error: "歌曲消失在茫茫的曲库中了" };
    }
    const lyricURL = `http://music.163.com/api/song/lyric?os=osx&id=${items[itemId].id}&lv=-1&kv=-1&tv=-1`;
    let meta;
    try {
      meta = await CosmosAsync.get(lyricURL, undefined, requestHeader);
    } catch (err) {
      return { error: "网络异常" };
    }
    let lrc = meta.lrc;
    if (!lrc || !lrc.lyric) {
      return { error: "歌词消失在茫茫的词库中了" };
    }
    let result = parseLyrics(lrc.lyric);
    let tLyric = meta.tlyric;
    if (tLyric && tLyric.lyric) {
      const { error, lyrics } = parseLyrics(tLyric.lyric);
      if (!error) {
        result.tlyrics = lyrics;
      }
    }
    return result;
  }

  async function updateTrack() {
    const meta = Player.data?.item.metadata;
    if (!meta) {
      sharedData = { error: "没有正在播放的歌曲" };
    }
    if (!Spicetify.URI.isTrack(Player.data.item.uri) && !Spicetify.URI.isLocalTrack(Player.data.item.uri)) {
      return;
    }
    const info = {
      duration: Number(meta.duration),
      album: meta.album_title,
      artist: meta.artist_name,
      title: meta.title,
      uri: Player.data.item.uri,
    }
    sharedData = { lyrics: [], tlyrics: [] };
    sharedData = await fetchNetease(info);
  }

  Player.addEventListener("songchange", updateTrack);

  updateTrack();

  async function tick() {
    const currentTime = Player.getProgress() / 1000;
    const duration = Player.getDuration() / 1000;
    const { error, lyrics, tlyrics } = sharedData;
    let result = {};
    if (error) {
      result = { lyric: error };
    } else if (duration && lyrics.length) {
      let currentIndex = -1;
      lyrics.forEach(({ startTime }, index) => {
        if (startTime && currentTime > startTime) {
          currentIndex = index;
        }
      });
      result.lyric = currentIndex === -1 ? "♪♪♪" : lyrics[currentIndex].text;
      if (tlyrics) {
        currentIndex = -1;
        tlyrics.forEach(({ startTime }, index) => {
          if (startTime && currentTime > startTime) {
            currentIndex = index;
          }
        });
        result.tlyric = currentIndex === -1 ? null : tlyrics[currentIndex].text;
      }
    } else if (!duration || lyrics.length === 0) {
      result = { error: "加载中……" };
    }

    try {
      const controller = new AbortController();
      const id = setTimeout(() => controller.abort(), 500);
      await fetch("http://localhost:12138", {
        method: "POST",
        mode: "no-cors",
        body: JSON.stringify(result),
        signal: controller.signal,
      });
      clearTimeout(id)
    } catch (err) {
    }

    worker.postMessage("lyricify-nvim-request-update");
  }

  Player.addEventListener("onplaypause", event => {
    if (event.data.isPaused) {
      worker.postMessage("lyricify-nvim-stop-request");
    } else {
      tick();
    }
  });
}
