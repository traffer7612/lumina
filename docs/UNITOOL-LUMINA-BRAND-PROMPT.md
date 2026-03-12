# Промпты для визуальных материалов бренда Lumina

Документ содержит готовые промпты для генерации картинок в **unitool.ai**, **DALL·E** (ChatGPT / OpenAI), **Nano Banana 2** и **Stable Diffusion**. Палитра и стилистика Lumina / luminadefi — единые для всех инструментов. При генерации конкретного креатива добавляйте в конец описание формата и сюжета (баннер, иконка, иллюстрация и т.д.).

---

## Если всё плохо генерит — делай так (баннер с текстом)

**Текст в картинках почти все модели коверкают.** Надёжный способ:

### Шаг 1: Сгенерировать только фон (без текста)

Используй **любую** модель. Один универсальный промпт — только фон, никаких букв:

```
Wide banner background, 16:9. Very dark blue-black, soft gradient with warm gold and subtle purple glow in the center. Minimal abstract shape: gentle curve or soft light ray, no people, no text, no letters, no words. Premium DeFi fintech style, clean, professional.
```

Сгенерируй несколько вариантов, выбери лучший.

### Шаг 2: Текст "luminatoken" добавить в редакторе

- **Canva** (canva.com) — бесплатно: загрузи картинку → Текст → напиши `luminatoken` → шрифт типа Outfit, Space Grotesk или любой современный sans-serif → цвет **#d4a853** (золотой), крупно, по центру.
- **Figma** — то же: картинка как фон, поверх текстовый слой "luminatoken", золотой, по центру.
- **Photoshop / Photopea** — то же: слой с текстом поверх фона.

Итог: баннер с идеально читаемым текстом, без искажений. Так делают в прод-дизайне, когда нужен точный текст.

---

## Бренд Lumina — базовый промпт (копируй в unitool.ai)

```
Brand: Lumina (Lumina Protocol). DeFi lending protocol: deposit collateral, borrow stablecoins, governance via LUMINA and veLUMINA. Non-custodial, on-chain. Tagline feel: "DeFi lending. On your terms."

Visual identity:
- Mood: premium, trustworthy, modern DeFi; dark theme with warm gold and subtle purple; professional, not playful.
- Palette (use strictly):
  - Background: very dark blue-black (#080810, #0f0f1a).
  - Surfaces: dark blue-grey (#161625, #1e1e32).
  - Primary accent: warm gold (#d4a853), dim gold (#9a7b3a), bright gold (#e8c070).
  - Secondary accent: violet/purple (#8b5cf6, #6d3fd8).
  - Optional: cyan (#06b6d4), success green (#22c55e).
  - Text: white and light grey (#8888a8, #5a5a78).
- Style: clean geometric shapes, subtle gradients (gold to purple or gold glow on dark), soft glow on key elements, no clutter. Optional: abstract vault/lock, charts, chains, or light rays suggesting security and growth.
- Typography feel: sans-serif, modern (like Outfit); optional monospace for numbers/code.
- Avoid: cartoon characters, meme style, neon rave, generic "crypto bro" clichés. Prefer minimal, product-led, and slightly luxurious.

Output: [здесь опиши формат: e.g. "Square logo mark 512px", "Twitter header 1500x500", "App store icon 1024px", "Hero illustration for landing page", "Telegram sticker set", "OG image 1200x630", etc.]
```

---

## Примеры конкретных запросов (добавляй после базового промпта)

**Логотип / знак**
- Output: Square logo mark, 512×512px, transparent or dark background. Symbol only: abstract "L" or vault/light motif in gold on dark, minimal, no text.

**Баннер для Twitter/X**
- Output: Twitter header 1500×500px. Dark background, gradient gold-to-purple glow top-center, "LUMINA" or "Lumina Protocol" clean typography, tagline "DeFi lending. On your terms." Optional: subtle chart or lock icon. No faces.

**OG-картинка для ссылок**
- Output: Open Graph image 1200×630px. Dark theme, gold accent, logo or wordmark "Lumina", short line "DeFi lending protocol" or "Deposit. Borrow. Govern." Centered, readable in small preview.

**Иконка приложения**
- Output: App icon 1024×1024px, rounded square. Single strong symbol (e.g. stylized L, vault, or light burst) in gold on #0f0f1a. No small text.

**Иллюстрация для лендинга**
- Output: Hero illustration, wide format. Dark blue-black base, soft radial gradient with gold/purple, abstract elements: vault, upward chart line, or rays. Minimal, no people. Premium DeFi feel.

**Стикеры / мелкие ассеты**
- Output: Set of 4–6 simple icons: lock, chart-up, vault, LUMINA coin, shield, wallet. Same palette (gold/violet on dark), flat or soft gradient, consistent line weight.

**Фон для презентации**
- Output: Presentation background 1920×1080. Very dark (#080810), subtle grid or radial fade, small gold/purple glow in corner or center. Space for title and body text. Professional.

---

## Промпты для DALL·E (ChatGPT / OpenAI)

DALL·E лучше реагирует на **короткие чёткие фразы** и названия цветов, а не HEX. Копируй целым блоком в ChatGPT (DALL·E) или в API.

**Общая стилистика для любого запроса:**  
*"Premium minimal design, dark blue-black background, warm gold and soft purple accents, no text unless specified, professional DeFi fintech style, clean geometry."*

### Логотип / знак
```
Minimal logo mark for a DeFi finance brand. Single abstract symbol: stylized letter L or a vault shape or soft light burst. Warm gold color on very dark blue-black background. Square composition, centered, no text. Professional, luxurious, clean vector style.
```

### Баннер (Twitter / соцсети)
```
Wide banner image, dark blue-black background with soft gradient. Warm gold and subtle purple glow in the center or top. Minimal abstract elements: gentle upward chart line or lock icon silhouette in gold. No people, no text. Premium fintech DeFi style, 16:9 aspect ratio.
```

### OG-картинка (превью ссылки)
```
Social media preview image. Very dark background, one bold warm gold accent (glow or simple shape). Centered composition, lots of empty space. Professional DeFi brand feel. No text. 1200x630 aspect ratio.
```

### Иконка приложения
```
App icon, square. Single strong symbol: abstract L or vault or coin in warm gold on very dark blue-black. Minimal, no text, rounded square format. Premium fintech style.
```

### Hero-иллюстрация для лендинга
```
Hero section illustration for a DeFi lending website. Dark blue-black base, soft radial gradient with warm gold and light purple. Abstract elements: vault, ascending line chart, or soft light rays. No people, no text. Wide format, minimal, premium and trustworthy mood.
```

### Фон для презентации
```
Presentation background. Very dark blue-black with subtle gold and purple glow in one corner. Minimal, professional, space for text overlay. No characters, no logos. Clean fintech style.
```

**Совет:** если DALL·E добавляет текст сам — в конце промпта явно напиши: *"No text, no letters, no words."* Для логотипа с буквой L можно оставить один символ, тогда уточни: *"Only one letter: L, stylized, in gold."*

### GPT Image — баннер с текстом "luminatoken"

Для ChatGPT (GPT Image / DALL·E) — один промпт, текст **luminatoken** прямо в кадре. GPT Image 1.5 хорошо выводит текст, можно копировать целиком.

```
Wide banner image, 16:9 aspect ratio. Dark blue-black background with soft warm gold and purple gradient glow. Minimal DeFi fintech style, premium and clean. In the center, large bold text: "luminatoken" in warm golden color, modern sans-serif, clearly readable. Optional: very subtle vault silhouette or soft chart line in the background. No other text, no people. Professional crypto token brand banner.
```

**Вариант короче (если лимит символов):**
```
Banner 16:9, dark blue-black background, gold and purple glow. Centered large text: "luminatoken" in warm gold, clean sans-serif, readable. Minimal DeFi style, no people, no other text.
```

---

## Промпты для Nano Banana 2

Бренд в промптах явно указан как **luminadefi** (Lumina Protocol, luminadefi.pro). Копируй целиком в Nano Banana 2.

**Базовый контекст (добавляй к любому запросу):**  
*Brand: luminadefi — Lumina Protocol, DeFi lending. Site: luminadefi.pro. Dark theme, warm gold and soft purple, premium minimal.*

### Логотип / знак
```
luminadefi logo mark. Lumina Protocol brand. Abstract L or vault or light burst, warm gold on dark blue-black. Minimal, no text, square. luminadefi.pro
```

### Баннер
```
luminadefi banner. Lumina Protocol, luminadefi.pro. Dark background, gold and purple glow, minimal chart or lock shape. No text. Wide format, premium DeFi.
```

### OG-картинка
```
luminadefi social preview. Lumina Protocol. Dark background, one gold accent glow, centered, minimal. luminadefi.pro. No text. 1200x630.
```

### Иконка приложения
```
luminadefi app icon. Lumina brand. Single symbol in warm gold on dark blue-black. L or vault or coin, minimal, rounded square. luminadefi.pro
```

### Hero / лендинг
```
luminadefi hero illustration. Lumina Protocol DeFi lending. Dark base, gold and purple gradient, vault or chart or rays. No people, no text. luminadefi.pro. Premium.
```

### Фон
```
luminadefi presentation background. Lumina Protocol. Very dark blue-black, subtle gold and purple glow. Minimal, space for text. luminadefi.pro
```

---

## Промпты для Stable Diffusion (баннер с текстом luminatoken)

Stable Diffusion плохо выводит точный текст — буквы часто искажает. Ниже промпт для баннера с надписью **luminatoken**; для надёжного текста лучше сгенерировать фон, затем добавить текст в редакторе или через inpainting.

### Баннер с текстом "luminatoken"

**Positive prompt:**
```
banner, wide format, 16:9, dark blue black background, very dark #0f0f1a, warm gold and soft purple gradient glow, minimal DeFi fintech style, premium, clean. Large bold text in center reading "luminatoken", golden color #d4a853, modern sans-serif typography, clear readable letters, no distortion. Subtle abstract elements: vault silhouette or soft chart line in background. Lumina token crypto brand, professional, high quality
```

**Negative prompt:**
```
blurry text, distorted letters, wrong spelling, extra limbs, cartoon, meme, neon, cluttered, ugly, lowres, watermark, signature
```

**Параметры (ориентир):**  
Resolution для баннера: 1024×576 или 1280×720 (16:9). Steps 25–35. CFG 7–9. Если используешь SDXL или модель с поддержкой текста (например Flux) — шанс на читаемый "luminatoken" выше.

**Если текст всё равно кривой:**  
1. Сгенерировать только фон (тот же промпт, но без фразы про "luminatoken").  
2. Добавить надпись **luminatoken** в Figma/Photoshop/Canva поверх картинки шрифтом в духе Outfit или любой современный sans-serif, цвет золотой (#d4a853).  
3. Либо использовать inpainting: замазать область текста на сгенерированном баннере и в промпте inpaint указать: *"large text luminatoken, golden color, clean sans-serif, centered"*.

---

## Какие модели хорошо рисуют текст

Для баннеров с надписью **luminatoken** (и другим точным текстом) лучше использовать модели, заточенные под текст:

| Модель | Где / как | Текст |
|--------|-----------|--------|
| **Nano Banana Pro** (Gemini 3 Pro Image) | nano-banana2.ai и др. | Очень хорошо: 4K, glyph-aware, 40+ языков, печать 300 dpi. |
| **Google Imagen 4** | Google AI Studio, Vertex AI | Отлично: постеры, лейблы, UI, маркетинг, комиксы. |
| **GPT Image 1.5 / DALL·E** (OpenAI) | ChatGPT, API | Улучшенный текст: постеры, меню, инфографика. |
| **GLM-Image** | open-source | Сильно по тексту (лидер среди open-source по бенчмаркам), до 2048px, мультиязык. |
| **Flux** (например Flux.1 Pro) | разный софт | Лучше, чем SD 1.5/2.x; текст часто читаемый, но не идеальный. |
| **SDXL / SD 1.5–2.x** | Automatic1111, ComfyUI и т.д. | Текст рисует плохо — буквы путает и искажает. |

**Итог:** если все модели плохо генерируют текст — не борись с ними. Сгенерируй **только фон** (промпт в начале документа, раздел «Если всё плохо генерит»), затем добавь надпись **luminatoken** в Canva / Figma / Photopea. Так получишь гарантированно читаемый баннер за пару минут.

---

## Краткая палитра (для копирования в другие инструменты)

| Название   | HEX       | Использование      |
|-----------|-----------|--------------------|
| bg        | #080810   | Фон                |
| surface   | #0f0f1a   | Карточки, панели   |
| gold      | #d4a853   | Основной акцент    |
| gold-bright | #e8c070 | Кнопки, ховер      |
| accent    | #8b5cf6   | Вторичный акцент   |
| muted     | #8888a8   | Второстепенный текст |

---

## Домены и названия

- Сайт: luminadefi.pro, lumina.finance  
- Токены: LUMINA, veLUMINA  
- Продукт: Lumina Protocol
