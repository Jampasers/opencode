---
name: seo
description: Use when auditing crawlability, indexability, canonicals, redirects, or sitemaps; improving title tags, meta descriptions, heading structure, or internal linking; implementing metadata (Nuxt 4 useHead/useSeoMeta, Next.js 15 generateMetadata), Open Graph/Twitter cards, or JSON-LD structured data; improving Core Web Vitals; choosing SSR/SSG/ISR rendering; setting up hreflang; verifying Google Search Console; or doing keyword mapping and full SEO audits.
origin: merged from seo, seo-optimization
---

# SEO

Improve search visibility through technical correctness, performance, and content relevance — not gimmicks.

## When to Use

- Auditing crawlability, indexability, canonicals, redirects, or robots/sitemaps
- Improving title tags, meta descriptions, heading structure, and internal linking
- Implementing metadata APIs: Nuxt 4 `useHead`/`useSeoMeta`, Next.js 15 `generateMetadata`
- Adding or validating structured data (JSON-LD), Open Graph, and Twitter Cards
- Improving Core Web Vitals (LCP, INP, CLS)
- Choosing rendering strategy (SSR / SSG / ISR / SPA) for indexability
- Configuring hreflang for multilingual sites
- Verifying Google Search Console and monitoring its reports
- Keyword research, keyword-to-URL mapping, and cannibalization checks
- Running a full technical / on-page / performance / security SEO audit

## Principles

1. Fix technical blockers before content optimization.
2. One page should have one clear primary search intent.
3. Prefer long-term quality signals over manipulative patterns.
4. Mobile-first assumptions matter because indexing is mobile-first.
5. Recommendations should be page-specific and implementable.

## Technical SEO — Crawlability & Indexability

**Crawlability**

- `robots.txt` should allow important pages and block low-value surfaces
- No important page should be unintentionally `noindex`
- Important pages should be reachable within a shallow click depth
- Avoid redirect chains longer than two hops
- Canonical tags should be self-consistent and non-looping

**Indexability**

- Preferred URL format should be consistent (case, trailing slash, www vs non-www)
- Multilingual pages need correct hreflang if used
- Sitemaps should reflect the intended public surface
- No duplicate URLs should compete without canonical control

**URL rules**

- Lowercase, hyphen-separated, short, descriptive, primary keyword present
- Trailing-slash usage consistent (all with or all without)
- No dynamic parameters, session IDs, or tracking params in canonical URLs
- 301 redirects for all old/changed URLs; HTTP → HTTPS redirect (301, permanent)
- WWW vs non-www resolved with a 301 redirect

## Meta Tags — Nuxt 4

### useSeoMeta (recommended, reactive)

```typescript
useSeoMeta({
  title: 'Page Title - Site Name',
  titleTemplate: '%s | Site Name',
  description: 'Page description targeting primary keywords, 150–160 characters.',
  ogTitle: 'Page Title',
  ogDescription: 'Description for social sharing (max ~300 chars).',
  ogImage: 'https://example.com/og-image.jpg',
  ogImageWidth: 1200,
  ogImageHeight: 630,
  ogUrl: 'https://example.com/page',
  ogType: 'website',
  ogSiteName: 'Site Name',
  ogLocale: 'id_ID',
  twitterCard: 'summary_large_image',
  twitterTitle: 'Page Title',
  twitterDescription: 'Description for Twitter.',
  twitterImage: 'https://example.com/twitter-image.jpg',
  twitterSite: '@sitehandle',
  robots: 'index, follow',
})
```

### useHead (link/script/arbitrary head tags)

```typescript
useHead({
  title: 'Page Title - Site Name',
  titleTemplate: '%s | Site Name',
  link: [
    { rel: 'canonical', href: 'https://example.com/page' },
    { rel: 'alternate', hreflang: 'en', href: 'https://example.com/en/page' },
    { rel: 'alternate', hreflang: 'x-default', href: 'https://example.com/page' },
  ],
  meta: [
    { name: 'robots', content: 'index, follow' },
    { name: 'google-site-verification', content: 'VERIFICATION_CODE' },
    { name: 'msvalidate.01', content: 'BING_VERIFICATION_CODE' },
    { name: 'theme-color', content: '#ffffff' },
  ],
  script: [{ type: 'application/ld+json', children: JSON.stringify({ /* schema */ }) }],
})
```

### Config defaults and reusable composable

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  app: {
    head: {
      charset: 'utf-8',
      viewport: 'width=device-width, initial-scale=1',
      titleTemplate: '%s | Site Name',
    },
  },
})
```

```typescript
// composables/useSeo.ts — one call per page
export function usePageSeo(options: {
  title: string
  description: string
  ogImage?: string
  canonical?: string
  type?: string
  robots?: string
  jsonld?: Record<string, unknown>
}) {
  const config = useRuntimeConfig()
  const route = useRoute()
  const baseUrl = config.public.siteUrl || 'https://example.com'
  const canonical = options.canonical || `${baseUrl}${route.path}`

  useSeoMeta({
    title: options.title,
    description: options.description,
    ogTitle: options.title,
    ogDescription: options.description,
    ogImage: options.ogImage || `${baseUrl}/images/og-default.jpg`,
    ogUrl: canonical,
    ogType: options.type || 'website',
    twitterCard: 'summary_large_image',
  })
  useHead({
    link: [{ rel: 'canonical', href: canonical }],
    meta: [{ name: 'robots', content: options.robots || 'index, follow' }],
    ...(options.jsonld && {
      script: [{ type: 'application/ld+json', children: JSON.stringify(options.jsonld) }],
    }),
  })
}
```

```typescript
// pages/blog/[slug].vue
usePageSeo({
  title: `${article.value.title} - Blog`,
  description: article.value.excerpt,
  ogImage: article.value.ogImage,
  type: 'article',
  jsonld: { '@context': 'https://schema.org', '@type': 'Article', headline: article.value.title },
})
```

## Meta Tags — Next.js 15

### Static metadata

```typescript
// app/about/page.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'About Us - Site Name',
  description: 'Learn more about our company, mission, and team.',
  openGraph: {
    title: 'About Us - Site Name',
    description: 'Learn more about our company, mission, and team.',
    url: 'https://example.com/about',
    siteName: 'Site Name',
    images: [{ url: 'https://example.com/og-about.jpg', width: 1200, height: 630 }],
    locale: 'id_ID',
    type: 'website',
  },
  twitter: { card: 'summary_large_image', title: 'About Us', images: ['https://example.com/twitter-about.jpg'] },
  robots: { index: true, follow: true },
  alternates: {
    canonical: 'https://example.com/about',
    languages: { 'en': 'https://example.com/en/about', 'id': 'https://example.com/id/about' },
  },
}
```

### Dynamic metadata (generateMetadata)

```typescript
// app/blog/[slug]/page.tsx
export async function generateMetadata(
  { params }: { params: Promise<{ slug: string }> },
): Promise<Metadata> {
  const { slug } = await params
  const article = await fetchArticle(slug)
  return {
    title: `${article.title} - Blog`,
    description: article.excerpt,
    openGraph: {
      title: article.title,
      description: article.excerpt,
      url: `https://example.com/blog/${slug}`,
      images: [{ url: article.ogImage, width: 1200, height: 630 }],
      type: 'article',
      publishedTime: article.publishedAt,
      authors: [article.author],
    },
    twitter: { card: 'summary_large_image', images: [article.ogImage] },
    alternates: { canonical: `https://example.com/blog/${slug}` },
    robots: { index: true, follow: true },
  }
}
```

### Root layout defaults

```typescript
// app/layout.tsx
export const metadata: Metadata = {
  title: { template: '%s | Site Name', default: 'Site Name — Tagline' },
  description: 'Default site description for search engines.',
  metadataBase: new URL('https://example.com'),
  openGraph: { siteName: 'Site Name', type: 'website', locale: 'id_ID' },
  twitter: { card: 'summary_large_image', creator: '@sitehandle' },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, 'max-video-preview': -1, 'max-image-preview': 'large', 'max-snippet': -1 },
  },
  verification: { google: 'GOOGLE_VERIFICATION_CODE', yandex: 'YANDEX_VERIFICATION_CODE', yahoo: 'YAHOO_VERIFICATION_CODE' },
}
```

### JSON-LD in Next.js

```tsx
const jsonLd = { '@context': 'https://schema.org', '@type': 'Article', headline: article.title /* ... */ }
return (
  <>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
    <ArticlePage article={article} />
  </>
)
```

## Open Graph & Twitter Cards

| Property | Required | Description | Recommended Value |
|----------|----------|-------------|-------------------|
| `og:title` | Yes | Page title for social shares | 40–60 chars |
| `og:description` | Yes | Description for social shares | 150–200 chars |
| `og:image` | Yes | Social share image | 1200×630px, <5MB, JPG/PNG/WebP |
| `og:url` | Yes | Canonical URL | Full absolute URL |
| `og:type` | No | Content type | `website`, `article`, `product` |
| `og:site_name` | No | Site name | Brand name |
| `og:locale` | No | Language & region | `id_ID`, `en_US` |
| `og:image:width` / `:height` | No | Image dimensions | 1200 / 630 |
| `og:video`, `og:audio` | No | Media URL | Full URL |
| `fb:app_id` | No | Facebook app ID for insights | Numeric ID |

| Property | Required | Description | Recommended Value |
|----------|----------|-------------|-------------------|
| `twitter:card` | Yes | Card type | `summary_large_image` or `summary` |
| `twitter:site` | Yes | Twitter handle | `@username` |
| `twitter:title` | Yes | Page title | 40–70 chars |
| `twitter:description` | Yes | Page description | 150–200 chars |
| `twitter:image` | Yes | Share image | 1200×675px (2:1) |
| `twitter:creator` | No | Author handle | `@username` |
| `twitter:domain` | No | Site domain | `example.com` |
| `twitter:player` | No | Video player URL | Full URL |
| `twitter:app:name:iphone` | No | iOS app name | Name |

Dynamic OG images in Nuxt: use the Nuxt OG Image module — `defineOgImage({ component: 'OgTemplate', props: { title, description }, url })`.

## Structured Data (JSON-LD)

**General rules**

- Use `@context: "https://schema.org"`; add via `<script type="application/ld+json">`
- Never duplicate identical schemas on the same page; keep `@id` references consistent and resolvable
- Keep schemas concise — only include properties you actually have; validate via Google Rich Results Test

### Organization (homepage/About, via layout or global component)

```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Company Name",
  "url": "https://example.com",
  "logo": "https://example.com/logo.png",
  "description": "Company description.",
  "foundingDate": "2020-01-01",
  "address": { "@type": "PostalAddress", "streetAddress": "...", "addressLocality": "...", "addressRegion": "...", "postalCode": "...", "addressCountry": "ID" },
  "contactPoint": { "@type": "ContactPoint", "telephone": "+62-21-12345678", "contactType": "customer service", "availableLanguage": ["Indonesian", "English"] },
  "sameAs": ["https://facebook.com/company", "https://twitter.com/company", "https://instagram.com/company", "https://linkedin.com/company/company"]
}
```

### Article

```json
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "The Complete Guide to SEO",
  "description": "A comprehensive guide covering on-page, technical SEO, and content strategy.",
  "image": "https://example.com/images/seo-guide.jpg",
  "author": { "@type": "Person", "name": "Author Name", "url": "https://example.com/authors/author-name", "sameAs": ["https://twitter.com/author"] },
  "datePublished": "2025-01-15T08:00:00+07:00",
  "dateModified": "2025-03-20T14:30:00+07:00",
  "publisher": { "@type": "Organization", "name": "Company Name", "logo": { "@type": "ImageObject", "url": "https://example.com/logo.png" } },
  "mainEntityOfPage": { "@type": "WebPage", "@id": "https://example.com/blog/seo-guide" },
  "wordCount": 2500,
  "inLanguage": "id",
  "isAccessibleForFree": true
}
```

Variants: `NewsArticle` (time-sensitive news; add dateline, printColumn), `BlogPosting` (blog entries, same as Article), `TechArticle` (technical docs; add proficiencyLevel, dependencies), `ScholarlyArticle` (academic/educational).

### Product (with Offer)

```json
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Premium Widget Pro",
  "image": ["https://example.com/images/widget-pro-1.jpg"],
  "description": "High-quality premium widget for professional use.",
  "sku": "WGT-PRO-001",
  "mpn": "WGT-PRO-001",
  "brand": { "@type": "Brand", "name": "WidgetCo" },
  "offers": {
    "@type": "Offer",
    "url": "https://example.com/products/widget-pro",
    "priceCurrency": "IDR",
    "price": "299000",
    "priceValidUntil": "2025-12-31",
    "itemCondition": "https://schema.org/NewCondition",
    "availability": "https://schema.org/InStock",
    "seller": { "@type": "Organization", "name": "Company Name" },
    "hasMerchantReturnPolicy": { "@type": "MerchantReturnPolicy", "returnPolicyCategory": "https://schema.org/MerchantReturnFiniteReturnWindow", "merchantReturnDays": 30, "returnMethod": "https://schema.org/ReturnByMail", "returnFees": "https://schema.org/FreeReturn" },
    "shippingDetails": { "@type": "OfferShippingDetails", "shippingDestination": { "@type": "DefinedRegion", "addressCountry": "ID" }, "deliveryTime": { "@type": "ShippingDeliveryTime", "handlingTime": { "@type": "QuantitativeValue", "minValue": 1, "maxValue": 2, "unitCode": "DAY" }, "transitTime": { "@type": "QuantitativeValue", "minValue": 2, "maxValue": 5, "unitCode": "DAY" } }, "shippingRate": { "@type": "MonetaryAmount", "value": 25000, "currency": "IDR" } }
  },
  "aggregateRating": { "@type": "AggregateRating", "ratingValue": "4.7", "bestRating": "5", "ratingCount": "342", "reviewCount": "298" },
  "review": [{ "@type": "Review", "reviewRating": { "@type": "Rating", "ratingValue": "5" }, "author": { "@type": "Person", "name": "Customer Name" }, "reviewBody": "Excellent product." }],
  "category": "Widgets > Premium"
}
```

### FAQPage

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    { "@type": "Question", "name": "What is SEO?", "acceptedAnswer": { "@type": "Answer", "text": "SEO is the practice of optimizing websites to rank higher in search results." } }
  ]
}
```

Rules: one FAQPage per page; each Question exactly one acceptedAnswer; answers concise (<500 chars); do not hide answers behind accordion toggles (Google may treat as hidden content); minimum 2 questions, 3–10 recommended.

### BreadcrumbList

```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "Home", "item": "https://example.com/" },
    { "@type": "ListItem", "position": 2, "name": "Blog", "item": "https://example.com/blog" },
    { "@type": "ListItem", "position": 3, "name": "SEO Best Practices", "item": "https://example.com/blog/seo-best-practices" }
  ]
}
```

### LocalBusiness

```json
{
  "@context": "https://schema.org",
  "@type": "LocalBusiness",
  "@id": "https://example.com",
  "name": "Business Name",
  "image": "https://example.com/storefront.jpg",
  "telephone": "+62-21-12345678",
  "priceRange": "$$",
  "address": { "@type": "PostalAddress", "streetAddress": "...", "addressLocality": "...", "addressRegion": "...", "postalCode": "...", "addressCountry": "ID" },
  "geo": { "@type": "GeoCoordinates", "latitude": -6.2088, "longitude": 106.8456 },
  "openingHoursSpecification": [{ "@type": "OpeningHoursSpecification", "dayOfWeek": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], "opens": "09:00", "closes": "18:00" }],
  "sameAs": ["https://facebook.com/business", "https://instagram.com/business"]
}
```

### WebSite with SearchAction

```json
{
  "@context": "https://schema.org",
  "@type": "WebSite",
  "name": "Site Name",
  "url": "https://example.com",
  "potentialAction": {
    "@type": "SearchAction",
    "target": { "@type": "EntryPoint", "urlTemplate": "https://example.com/search?q={search_term_string}" },
    "query-input": "required name=search_term_string"
  }
}
```

### VideoObject

```json
{
  "@context": "https://schema.org",
  "@type": "VideoObject",
  "name": "Video Title",
  "description": "Video description with keywords.",
  "thumbnailUrl": "https://example.com/video-thumbnail.jpg",
  "uploadDate": "2025-01-15T08:00:00+07:00",
  "duration": "PT15M30S",
  "contentUrl": "https://example.com/videos/video.mp4",
  "embedUrl": "https://example.com/embed/video-id"
}
```

### Schema placement strategy

| Page Type | Required Schema | Optional Schema |
|-----------|----------------|-----------------|
| Homepage | Organization | LocalBusiness, WebSite (SearchAction) |
| About | Organization, BreadcrumbList | — |
| Blog Post | Article, BreadcrumbList | FAQ (if applicable), Person (author) |
| Product | Product, BreadcrumbList | FAQ (if Q&A exists) |
| FAQ | FAQPage, BreadcrumbList | — |
| Contact | Organization | LocalBusiness |
| Category/Listing | BreadcrumbList | ItemList, CollectionPage |
| Search Results | — | SearchResultsPage, WebSite (SearchAction) |

## Canonical URLs

**Best practices**

- Every page MUST have a self-referencing canonical URL (except pagination)
- Use absolute URLs (including `https://` and domain); strip tracking/UTM params
- Trailing slash: pick one and stick with it; www vs non-www: pick one via canonical + redirect
- Never use canonical for "preferred domain" redirects — use 301 redirects
- Pagination: `rel=next`/`rel=prev` OR point to page 1 (Google's guidance shifted)

**Decision matrix**

| Scenario | Canonical URL | Notes |
|----------|---------------|-------|
| Single page version | Self-referencing | `https://example.com/page` |
| www vs non-www | Active domain | Redirect old → new, canon to new |
| HTTP vs HTTPS | HTTPS | Force HTTPS redirect + HTTPS canon |
| Trailing slash | Consistent choice | All with or all without |
| URL params (sort/filter) | Clean URL | `?sort=asc&page=2` → clean URL or page 1 |
| Paginated content | Self-referencing OR page 1 | Per Google's evolving guidance |
| Print/PDF version | Original page | rel=canonical to HTML version |
| AMP pages | Original page | AMP → canonical to original |
| Syndicated content | Original source | Point to original publisher's URL |
| UTM parameters | Clean URL | Strip tracking params |

Nuxt: `useHead({ link: [{ rel: 'canonical', href: `${baseUrl}${useRoute().path}` }] })`. Next.js: `metadata.alternates.canonical` (static or via `generateMetadata`).

## Hreflang

- Must be bidirectional: page A links to page B AND page B links to page A
- Include `x-default` fallback; self-referencing hreflang entry required
- Use ISO 639-1 language codes + ISO 3166-1 Alpha 2 region codes (`en`, `id`, `en-US`, `id-ID`)
- Implement via `<link>` tags in `<head>`, HTTP headers, or sitemap; keep sitemap and head tags consistent

```html
<link rel="alternate" hreflang="en" href="https://example.com/en/page" />
<link rel="alternate" hreflang="id" href="https://example.com/id/page" />
<link rel="alternate" hreflang="ja" href="https://example.com/ja/page" />
<link rel="alternate" hreflang="x-default" href="https://example.com/en/page" />
```

```typescript
// Nuxt 4
const langs = [
  { code: 'en', url: 'https://example.com/en' },
  { code: 'id', url: 'https://example.com/id' },
  { code: 'x-default', url: 'https://example.com/en' },
]
const currentPath = useRoute().path.replace(/^\/(en|id)\//, '/')
useHead({
  link: [
    { rel: 'canonical', href: `https://example.com${useRoute().path}` },
    ...langs.map(lang => ({ rel: 'alternate', hreflang: lang.code, href: `${lang.url}${currentPath}` })),
  ],
})

// Next.js 15
export const metadata: Metadata = {
  alternates: {
    canonical: 'https://example.com/en/page',
    languages: { 'en': 'https://example.com/en/page', 'id': 'https://example.com/id/page', 'x-default': 'https://example.com/en/page' },
  },
}
```

Sitemap-based hreflang: add `<xhtml:link rel="alternate" hreflang="..." href="..."/>` children under each `<url>`.

## Sitemaps

**Structure guidelines**

- Max 50,000 URLs and 50MB uncompressed per sitemap file; use a sitemap index beyond that
- Include `lastmod` (W3C datetime); compress with gzip (`*.xml.gz`)
- Set `changefreq`/`priority` thoughtfully — don't set everything to `daily`/`1.0`
- Submit the sitemap in robots.txt AND Google Search Console AND Bing Webmaster Tools
- Sitemaps should contain only the intended public surface (exclude admin, auth, API, previews)

| changefreq | When to Use |
|-------|-------------|
| `always` | Live scores, stock tickers (rarely appropriate) |
| `hourly` | News, frequently updated content |
| `daily` | Blog, articles, products with frequent changes |
| `weekly` | Static product/category/general pages |
| `monthly` | About, contact, evergreen content |
| `yearly` | Legal pages, privacy policy, terms |
| `never` | Archived content (use sparingly) |

| priority | When to Use |
|-------|-------------|
| `1.0` | Homepage only |
| `0.8` | Key landing pages, major categories |
| `0.6` | Blog posts, product pages, standard content |
| `0.4` | Tag pages, archive pages |
| `0.2` | Utility pages, paginated pages |
| `0.0` | Avoid — effectively tells search engines to ignore |

```typescript
// Next.js 15 — app/sitemap.ts (return an index-style array pointing to child sitemaps for large sites)
import type { MetadataRoute } from 'next'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const baseUrl = 'https://example.com'
  const staticPages = [
    { url: baseUrl, lastModified: new Date(), changeFrequency: 'weekly' as const, priority: 1 },
    { url: `${baseUrl}/about`, lastModified: new Date(), changeFrequency: 'monthly' as const, priority: 0.8 },
  ]
  const articles = await fetch(`${baseUrl}/api/articles`).then(res => res.json())
  const articlePages = articles.map((a: any) => ({
    url: `${baseUrl}/blog/${a.slug}`,
    lastModified: new Date(a.updatedAt),
    changeFrequency: 'weekly' as const,
    priority: 0.6,
  }))
  return [...staticPages, ...articlePages]
}
```

```typescript
// Nuxt 4 — nuxt.config.ts
export default defineNuxtConfig({
  modules: ['@nuxtjs/sitemap'],
  sitemap: {
    hostname: 'https://example.com',
    gzip: true,
    defaults: { changefreq: 'weekly', priority: 0.5, lastmod: new Date().toISOString() },
    exclude: ['/admin/**', '/auth/**', '/api/**', '/_nuxt/**', '/404', '/500'],
    sources: ['/api/__sitemap__/articles'],
  },
})

// server/api/__sitemap__/articles.ts
export default defineSitemapEventHandler(async () => {
  const articles = await fetchArticles()
  return articles.map(a => ({ loc: `/blog/${a.slug}`, lastmod: a.updatedAt, changefreq: 'weekly', priority: 0.6 }))
})
```

## robots.txt

- Must be at the root (`https://example.com/robots.txt`, returns 200)
- Allow public content (`Allow: /`), disallow admin, auth, API, internal, staging paths
- Point to sitemap(s); use `Disallow: /` only for non-production domains
- Use `noindex` meta tag as a supplement, not a replacement, for robots.txt
- `Crawl-delay` only works for some crawlers; don't over- or under-block crawl budget

```txt
User-agent: *
Allow: /

Disallow: /admin/
Disallow: /auth/
Disallow: /api/
Disallow: /_nuxt/
Disallow: /_next/static/chunks/
Disallow: /server/
Disallow: /temp/
# Duplicate-content patterns
Disallow: /*?sort=
Disallow: /*?page=
Disallow: /*?filter=
Disallow: /*/amp/

Allow: /_next/static/css/
Allow: /_next/static/media/
Allow: /_nuxt/static/

Crawl-delay: 5

Sitemap: https://example.com/sitemap.xml
Sitemap: https://example.com/sitemap-articles.xml
```

```typescript
// Next.js 15 — app/robots.ts
import type { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  const baseUrl = 'https://example.com'
  return {
    rules: [
      { userAgent: '*', allow: '/', disallow: ['/admin/', '/auth/', '/api/'] },
      { userAgent: 'GPTBot', disallow: '/' },
    ],
    sitemap: [`${baseUrl}/sitemap.xml`, `${baseUrl}/sitemap-articles.xml`],
  }
}

// Nuxt 4 — modules: ['@nuxtjs/robots']; robots: { allowNonIndexablePaths: false } (disallowAll: true for staging)
```

| User-Agent | Crawler | Typical Behavior |
|------------|---------|-----------------|
| `Googlebot` (+ `-Image`, `-News`, `-Video`) | Google | Indexes content, follows links |
| `Bingbot` | Bing | Indexes content |
| `Slurp` | Yahoo | Outdated; Yahoo uses Bing |
| `DuckDuckBot` | DuckDuckGo | Indexes content |
| `YandexBot`, `Baiduspider` | Yandex, Baidu | Index content |
| `GPTBot` | OpenAI | Scrapes for training (often blocked) |
| `CCBot` | Common Crawl | Scrapes for dataset |
| `Applebot` | Apple | Indexes for Siri/Spotlight |

## Core Web Vitals

| Metric | Measures | Good | Needs Work | Poor |
|--------|----------|------|------------|------|
| **LCP** | Loading performance (perceived load speed) | ≤2.5s | 2.5–4.0s | >4.0s |
| **INP** (replaced FID March 2024) | Interactivity / responsiveness | ≤200ms | 200–500ms | >500ms |
| **CLS** | Visual stability | ≤0.1 | 0.1–0.25 | >0.25 |

### LCP (<2.5s)

| Element Type | Typical Cause | Solution |
|--------------|---------------|----------|
| Hero image | Large unoptimized image | WebP/AVIF, responsive srcset, preload |
| Heading text | Web font loading | `font-display: swap`, preload fonts |
| Image gallery | Multiple large images | Lazy load below-fold, compress hero |
| Video poster | Large poster image | Optimize poster, preload |
| Background image | Heavy CSS background | Switch to `<img>` with preload |

Checklist: preload the LCP image with `fetchpriority="high"`; serve WebP/AVIF; use `srcset`/`sizes`; cap dimensions at display size ×2 (retina); compress hero to <100KB (or as small as acceptable); inline critical CSS; defer non-critical CSS/JS; preload critical fonts; `font-display: swap`; edge caching/CDN; HTTP/2 or HTTP/3; SSR above-the-fold content; remove render-blocking resources.

```typescript
// Nuxt 4 — preload LCP image
useHead({ link: [{ rel: 'preload', as: 'image', href: 'https://cdn.example.com/images/hero.webp', fetchpriority: 'high' }] })
```

```tsx
// Next.js — next/image auto-preloads with priority
<Image src="/hero.webp" alt="Hero" width={1200} height={630} priority fetchPriority="high" />
```

Critical CSS: Nuxt `@nuxtjs/critical` (`enabled: true, extract: true`); Next.js `experimental.optimizeCss` with `critters`.

### INP (<200ms)

| Issue | Cause | Solution |
|-------|-------|----------|
| Long tasks (>50ms) | Heavy JS on main thread | Code splitting, web workers, idle callbacks |
| Slow event handlers | Complex DOM work in handlers | Debounce/throttle, simplify handlers |
| Layout thrashing | Read/write DOM cycles forcing reflow | Batch DOM reads before writes |
| Third-party scripts | Analytics, chat, social widgets | Defer, lazy load, or self-host |
| Large DOM size | Complex component trees | Virtual scrolling, fewer components |

Checklist: break up long tasks (<50ms each); use `requestAnimationFrame`/`requestIdleCallback`; debounce scroll/resize; throttle input handlers; move heavy computation to Web Workers; lazy load below-the-fold components; defer non-critical third-party scripts; self-host analytics; minimize DOM depth/count; `content-visibility: auto` for offscreen content; preconnect to third-party origins; avoid `document.write`.

```typescript
// workers/search.worker.ts
self.onmessage = (e: MessageEvent) => {
  const { data, query } = e.data
  self.postMessage(heavySearch(data, query))
}
const worker = new Worker(new URL('../workers/search.worker.ts', import.meta.url))
worker.postMessage({ data: articleList, query: 'seo' })
worker.onmessage = (e) => { results.value = e.data }
```

### CLS (<0.1)

| Cause | Example | Solution |
|-------|---------|----------|
| Images without dimensions | `<img>` with no width/height | Explicit `width`/`height` + `aspect-ratio` |
| Ad injects | Dynamic ad insertion | Reserve ad slot space, min-height |
| Web font swap | FOIT → visible | `font-display: swap` |
| Dynamic content | Cookie banners/popups above flow | Reserve space or position fixed |
| Third-party embeds | YouTube, Twitter, maps load late | min-height container |
| Lazy-loaded images | Load and push content down | `aspect-ratio` CSS |

Checklist: set `width`/`height` on `<img>`/`<video>`; use CSS `aspect-ratio` for responsive media; `font-display: swap` for all `@font-face`; reserve space for ads/embeds; never insert content above visible content; `position: fixed/absolute` for overlays; pre-specify dimensions for `object-fit: cover`; animate only `transform`/`opacity`; use `size-adjust` on fallback fonts.

```css
img, video { max-width: 100%; height: auto; aspect-ratio: attr(width) / attr(height); }
.hero-image { aspect-ratio: 16 / 9; }
.image-container { position: relative; width: 100%; aspect-ratio: 1200 / 630; }
```

### Framework CWV configuration

```typescript
// Nuxt 4 — nuxt.config.ts (highlights)
export default defineNuxtConfig({
  ssr: true,
  nitro: { minify: true, compressPublicAssets: true },
  experimental: { inlineSSRStyles: true },
  image: { format: ['webp', 'avif'], screens: { xs: 320, sm: 640, md: 768, lg: 1024, xl: 1280, xxl: 1536 } },
  app: { head: { link: [
    { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
    { rel: 'preconnect', href: 'https://cdn.example.com', crossorigin: '' },
  ] } },
})

// Next.js 15 — next.config.ts (highlights)
const nextConfig: NextConfig = {
  experimental: { optimizePackageImports: ['lucide-react', '@radix-ui/react-icons'], optimizeCss: true, webpackBuildWorker: true },
  images: { formats: ['image/avif', 'image/webp'], deviceSizes: [640, 768, 1024, 1280, 1536] },
  compress: true,
}
```

### Monitoring CWV

| Tool | Purpose |
|------|---------|
| Google PageSpeed Insights (`pagespeed.web.dev`) | Lab + field data for any URL |
| Lighthouse (Chrome DevTools) | Lab data, actionable recommendations |
| CrUX (BigQuery / CrUX API) | Real-user field data |
| Search Console — Core Web Vitals | Field data grouped by URL |
| `web-vitals` JS library | Real-user monitoring (RUM) |
| Sentry / Datadog / New Relic | Integrated RUM with error tracking |

```typescript
// Nuxt 4 — plugins/web-vitals.client.ts
export default defineNuxtPlugin(() => {
  import('web-vitals').then(({ onLCP, onINP, onCLS }) => {
    const send = (metric: any) => navigator.sendBeacon('/api/vitals', JSON.stringify({
      name: metric.name, value: metric.value, rating: metric.rating,
      delta: metric.delta, id: metric.id, url: window.location.href,
    }))
    onLCP(send); onINP(send); onCLS(send)
  })
})
```

## Rendering Strategy (SSR/SSG)

| Strategy | SEO | Performance | Use Case |
|----------|-----|-------------|----------|
| **SSR** | Excellent — full HTML to crawlers | Higher TTFB, lower FCP/LCP | Indexed, dynamic pages |
| **SSG** | Excellent — pre-rendered HTML | Fastest possible | Blog, docs, landing pages |
| **ISR** | Excellent — SSG with updates | Near-SSG speed | Large sites with periodic updates |
| **SPA** | Poor — crawlers may not execute JS | Fast after JS loads | Apps behind login |
| **RSC** | Good — hybrid | Depends on composition | Modern Next.js apps |

| Content Type | Recommended Strategy | Rationale |
|--------------|---------------------|-----------|
| Blog posts | SSG | Infrequent changes, fastest delivery |
| Product pages | ISR (revalidate hourly/daily) | Dynamic pricing/stock but needs indexing |
| Category/Listing | SSR or ISR | Changes often, must be indexable |
| Homepage | SSG or ISR (5–15 min) | Key page, fast + fresh |
| Admin/Dashboard | SPA-only (noindex) | Behind auth |
| Landing pages | SSG | Static, campaign-specific |
| News articles | SSR with CDN caching | Immediate indexing + frequent updates |
| User profiles | SSR with CDN | Dynamic but indexable (if public) |
| Search results | SSR (noindex) | Useful to users, avoid duplicates |

```typescript
// Nuxt 4 — hybrid per-route
export default defineNuxtConfig({
  ssr: true,
  routeRules: {
    '/': { prerender: true },
    '/blog/**': { prerender: true },
    '/products/**': { swr: 3600 },
    '/admin/**': { ssr: false },
    '/news/**': { swr: 300 },
  },
})

// Next.js 15 — per-page exports
export const dynamic = 'force-static'   // static
export const revalidate = 3600          // ISR (seconds)
export const dynamic = 'force-dynamic'  // dynamic
// next.config.ts: output: 'export'     // full static export
```

**SSR best practices for SEO:** crawlers must receive fully rendered HTML (verify with URL Inspection); do not lazy-load critical above-the-fold content; use streaming SSR for faster TTFB; configure CDN caching (`Cache-Control: public, s-maxage=...`); avoid JS-only content crawlers can't see; correct status codes (200 content, 404 missing, 301 moved); server-side 301s, not JS redirects.

```bash
curl -H "User-Agent: Googlebot" https://example.com/page | head -100
```

## On-Page SEO

**Title tags** — ~50–60 characters; primary keyword near the front; legible to humans, not stuffed.

**Meta descriptions** — ~120–160 characters; describe the page honestly; include the main topic naturally.

**Headings** — one clear `H1` containing the primary keyword; `H2`/`H3` reflect actual content hierarchy; never skip levels for styling.

**Keyword mapping** — 1) define search intent; 2) gather realistic keyword variants; 3) prioritize by intent match, likely value, competition; 4) map one primary keyword/theme to one URL; 5) detect and avoid cannibalization.

**Internal linking** — link from strong pages to pages you want to rank; descriptive anchor text (no "click here"); backfill links from new pages to relevant existing ones; 2–5 internal links per page.

**Content quality** — original content (no thin/duplicate pages); minimum ~300 words on indexable pages; primary keyword in title, H1, first paragraph; short paragraphs (2–4 sentences); lists/tables/headings break up text; descriptive alt text; no broken links.

**Images** — descriptive `alt`; WebP/AVIF; explicit dimensions; `loading="lazy"` below the fold; LCP hero `fetchpriority="high"`; ≤200KB per image ideally; descriptive filenames.

## Google Search Console

| Method | Difficulty | Persistence | Notes |
|--------|-----------|-------------|-------|
| DNS TXT record | Easy | Permanent until removed | Preferred — survives redeploy |
| HTML file upload | Easy | Until file removed | Works for static hosting |
| HTML `<meta>` tag | Easy | Survives in head | Must be in layout/head |
| Google Analytics / GTM | Easy | Via GA/GTM | Requires existing snippet |
| Domain name provider | Easy | DNS-level | Recommended for domain property |

```typescript
// Nuxt 4 — nuxt.config.ts (or runtimeConfig for per-env)
app: { head: { meta: [{ name: 'google-site-verification', content: process.env.GOOGLE_VERIFICATION_CODE }] } }

// Next.js 15 — app/layout.tsx metadata
verification: { google: 'GOOGLE_VERIFICATION_CODE', yandex: 'YANDEX_VERIFICATION_CODE', bing: 'BING_VERIFICATION_CODE' }
```

**Owner verification flow** — 1) add property; 2) choose method (DNS TXT or meta tag); 3) implement token in code; 4) click Verify; 5) submit sitemap; 6) request indexing for key pages; 7) set preferred domain; 8) configure international targeting if multilingual.

**Reports to monitor**

| Report | What to Look For | Frequency |
|--------|------------------|-----------|
| Performance | Impressions, clicks, CTR, avg position | Weekly |
| URL Inspection | Indexing issues, canonical mismatches | Per new page / when fixing |
| Index Coverage | Indexed vs excluded, errors | Weekly |
| Sitemaps | Submitted vs indexed URLs | After sitemap updates |
| Core Web Vitals | LCP, INP, CLS field data | Monthly |
| Mobile Usability | Mobile-specific issues | Monthly |
| Manual Actions | Penalties | After algorithm updates |
| Security Issues | Hacked content, malware | As notified |
| Links > Top Linked Pages | Authority flow | Monthly |
| Removals | Temporarily removed pages | As needed |

## SEO Audit Checklist

**Indexing & crawlability** — site indexed (`site:example.com` shows results); no unintended `noindex`; robots.txt allows necessary paths and is accessible at `/robots.txt` (200); sitemap accessible, valid XML, submitted to GSC + Bing; crawl errors addressed (404/500/soft 404); no orphan pages; descriptive internal anchor text; pagination `rel=next/prev` or canonical per current guidance.

**Meta tags** — unique `<title>` per page (<60 chars, keyword near front); unique meta description (150–160 chars); self-referencing canonical on every page; per-page `robots` correct; OG + Twitter tags on all shareable pages; OG image ≥1200×630, valid, accessible; no duplicate titles/descriptions.

**Structured data** — Organization on homepage; BreadcrumbList on content pages; Article/BlogPosting on blog; Product on product pages (valid offer, price, availability); FAQPage on FAQ pages (validated, one per page); all pass Rich Results Test; no missing required properties; no duplicate same-type schemas; `@id` references consistent.

**Core Web Vitals** — LCP ≤2.5s lab (Lighthouse throttled 4G) and field (CrUX); INP ≤200ms field; CLS ≤0.1 lab and field; explicit image dimensions/aspect-ratio; critical CSS inlined; render-blocking minimized; `font-display: swap`; third-party deferred/lazy; long tasks (<50ms) broken up.

**URL structure** — lowercase, hyphenated, short, descriptive; consistent trailing slash; no dynamic params in canonicals; no session IDs in URLs (cookies instead); 301s for changed URLs; www/non-www resolved with 301; HTTP → HTTPS 301.

**Internationalization** — hreflang on all multilingual pages; bidirectional; `x-default` set; sitemap and head tags match; correct ISO codes.

**Performance & mobile** — PageSpeed Insights ≥90 mobile and desktop; responsive design; tap targets ≥48px; no horizontal scrolling; font ≥16px mobile (prevents zoom); correct viewport meta; FCP ≤1.8s; TTI ≤3.8s; TBT ≤200ms; Speed Index ≤3.4s.

**Security** — HTTPS with valid SSL; no mixed content; correct `X-Robots-Tag` headers for non-HTML files (PDFs, images); `X-Frame-Options` set; no Search Console security warnings.

**Audit tools**

| Tool | Purpose |
|------|---------|
| Google Search Console | Indexing, performance, CWV, manual actions |
| Google PageSpeed Insights | CWV lab + field data |
| Google Rich Results Test | Validate structured data |
| Google URL Inspection Tool | Check individual URL indexing |
| Lighthouse (Chrome) | Full audit (performance, SEO, a11y) |
| Ahrefs Webmaster Tools | Backlinks, organic keywords, site audit |
| Screaming Frog SEO Spider | Crawl entire site for technical issues |
| W3C Validator / Schema.org Validator | Validate HTML / schemas |
| Bing Webmaster Tools | Bing/Yahoo indexing, sitemap submission |
| GTmetrix / WebPageTest | Performance waterfall / multi-location testing |
| SEO Site Checkup / SE Ranking | Automated audits / keyword tracking |

**Audit frequency** — Technical: monthly (deep crawl, index coverage); CWV: weekly while actively optimizing, else monthly; On-page: per new page / quarterly; Structured data: per new template / quarterly; Backlinks: monthly; Competitor analysis: quarterly; Mobile usability and security: monthly; Full audit: quarterly for active sites, otherwise bi-annually.

## Anti-Patterns

| Anti-pattern | Fix |
| --- | --- |
| keyword stuffing | write for users first |
| thin near-duplicate pages | consolidate or differentiate them |
| schema for content that is not actually present | match schema to reality |
| content advice without checking the actual page | read the real page first |
| generic "improve SEO" outputs | tie every recommendation to a page or asset |

## Quick Reference

```text
Title formula:            Primary Topic - Specific Modifier | Brand
Meta description formula: Action + topic + value proposition + one supporting detail
```

Audit output shape:

```text
[HIGH] Duplicate title tags on product pages
Location: src/routes/products/[slug].tsx
Issue: Dynamic titles collapse to the same default string, which weakens relevance and creates duplicate signals.
Fix: Generate a unique title per product using the product name and primary category.
```

**Required checks before launch** — 1) robots.txt and sitemap.xml accessible; 2) Google Search Console verified; 3) canonical URLs on every page; 4) no duplicate meta titles; 5) PageSpeed Insights ≥90; 6) structured data validates in Rich Results Test; 7) HTTPS enforced (301); 8) all 404s resolve to a custom 404 page (not 200); 9) hreflang correct if multilingual; 10) Open Graph preview works (https://opengraph.dev/).

## Related

- Skills: [react-performance](../react-performance/SKILL.md), [react-patterns](../react-patterns/SKILL.md), [brand-voice](../brand-voice/SKILL.md)
