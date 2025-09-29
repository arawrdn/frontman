---
date: 2025-01-29T10:30:00-08:00
researcher: Claude
git_commit: a1146e98f78fbcbef97d85ee1002605d4ceac63e
branch: main
repository: ask-the-llm
topic: "How routing works in cal.com monorepo for routes that work both on marketing website and app"
tags: [research, codebase, routing, next.js, app-router, monorepo]
status: complete
last_updated: 2025-01-29
last_updated_by: Claude
---

# Research: How Routing Works in Cal.com Monorepo for Routes That Work Both on Marketing Website and App

**Date**: 2025-01-29T10:30:00-08:00
**Researcher**: Claude
**Git Commit**: a1146e98f78fbcbef97d85ee1002605d4ceac63e
**Branch**: main
**Repository**: ask-the-llm

## Research Question
I want to add a new route that renders some page, it should work both on the marketing website of cal.com and also on the app. Please provide an overview how the routing works in this monorepo.

## Summary
Cal.com uses a unified Next.js 13+ App Router architecture instead of separate marketing and app applications. The routing system employs **route groups** to distinguish between public booking pages and authenticated app pages, while sharing the same codebase and infrastructure. The key insight is that there is no separate marketing website - instead, the main web application (`apps/web`) serves both marketing/public content and app functionality through context-aware routing patterns.

## Detailed Findings

### Monorepo Architecture
The cal.com monorepo contains only one web application at `apps/web/` that serves both purposes:
- **Main Application**: `apps/web/` - Unified Next.js app using App Router
- **API Services**: `apps/api/v1/` and `apps/api/v2/` - Separate API applications
- **Missing Applications**: `apps/website`, `apps/console`, `apps/auth` are referenced in configs but not present

### Core Routing Implementation

#### Route Groups Pattern (`apps/web/app/`)
The application uses Next.js route groups to separate contexts without affecting URLs:

**`(booking-page-wrapper)/`** - Public booking pages
- Layout: `app/(booking-page-wrapper)/layout.tsx:5-16`
- Uses `PageWrapper` with `isBookingPage={true}` flag
- Routes: `[user]/page.tsx`, `team/[slug]/[type]/page.tsx`, `org/[orgSlug]/[user]/[type]/page.tsx`

**`(use-page-wrapper)/`** - Authenticated app pages
- Layout: `app/(use-page-wrapper)/layout.tsx:6-41`
- Contains nested `(main-nav)` group for navigation
- Routes: `/auth/login`, `/event-types`, `/availability`, `/teams`

#### Context Detection (`lib/hooks/useIsBookingPage.ts:7-26`)
Runtime detection of page context using URL patterns:
```typescript
const isBookingPage = [
  "/booking", "/cancel", "/reschedule",
  "/team", "/d", "/apps/routing-forms/routing-link",
  "/forms/"
].some((route) => pathname?.startsWith(route));
```

### Shared Routing Patterns

#### 1. Multi-Context Component Resolution
Routes serve different components based on resolved data:
- `org/[orgSlug]/[user]/page.tsx:80-91` conditionally renders `TeamPage` or `UserPage`
- Single route handles multiple entity types through runtime component selection

#### 2. Organization Multi-Tenant Routing (`next.config.js:284-414`)
Custom domain support maps organization subdomains to internal routes:
```javascript
{
  ...orgDomainMatcherConfig.root,
  destination: `/team/${orgSlug}?isOrgProfile=1`,
},
{
  ...orgDomainMatcherConfig.user,
  destination: `/org/${orgSlug}/:user`,
}
```

#### 3. Cross-Context Form Routing
Routing forms accessible in both contexts through rewrites:
- `/forms/:formQuery*` → `/apps/routing-forms/routing-link/:formQuery*`
- Dynamic component loading: `apps/routing-forms/[...pages]/page.tsx:32-42`

#### 4. Unified Middleware (`middleware.ts:52-100`)
Single middleware handles both contexts:
- Route pattern detection and rewrites
- Security headers (CSP, X-Frame-Options)
- Embed support across all contexts
- Authentication flow management

### Configuration Architecture

#### Rewrite Rules (`next.config.js:284-414`)
- **Locale handling**: `/(locale)/:path*` → `/:path*`
- **Legacy support**: `/login` → `/auth/login`
- **Organization routing**: Custom domain mapping when `ORGANIZATIONS_ENABLED`
- **Form routing**: `/forms/*` to routing forms app

#### Route Discovery (`pagesAndRewritePaths.js:5-37`)
Automatic page discovery across route groups:
```javascript
glob.sync(
  "{pages,app,app/(booking-page-wrapper),app/(use-page-wrapper),app/(use-page-wrapper)/(main-nav)}/**/[^_]*.{tsx,js,ts}",
  { cwd: __dirname }
)
```

## Code References
- `apps/web/app/layout.tsx:97-162` - Root layout with global providers
- `apps/web/app/(booking-page-wrapper)/layout.tsx:11` - Booking page wrapper with `isBookingPage={true}`
- `apps/web/app/(use-page-wrapper)/(main-nav)/layout.tsx:16` - Main nav Shell integration
- `apps/web/next.config.js:289-363` - Rewrite rules and organization routing
- `apps/web/middleware.ts:63-87` - Cross-context middleware logic
- `apps/web/lib/hooks/useIsBookingPage.ts:7-26` - Context detection patterns
- `apps/web/pagesAndRewritePaths.js:70-77` - Organization route patterns

## Architecture Documentation

### Current Implementation Patterns
1. **Unified Application**: Single Next.js app serves both marketing and app functionality
2. **Route Groups**: Logical separation without URL impact using `(group-name)` syntax
3. **Context-Aware Components**: Runtime component selection based on data and URL patterns
4. **Multi-Tenant Routing**: Organization subdomains map to internal routes
5. **Legacy Integration**: App Router coexists with Pages Router through adapter pattern

### How to Add Cross-Context Routes
Based on existing patterns, to add a route that works in both contexts:

1. **Create in booking wrapper**: Add route in `app/(booking-page-wrapper)/your-route/page.tsx`
2. **Use shared components**: Leverage existing `PageWrapper` with appropriate flags
3. **Add context detection**: Update `useIsBookingPage.ts` if special handling needed
4. **Configure rewrites**: Add URL rewrites in `next.config.js` if custom patterns required
5. **Test both contexts**: Ensure route works in both authenticated and public scenarios

### Security and Performance Considerations
- **CSP nonce handling**: Consistent across all routes via middleware
- **Embed support**: Special headers for embeddable content
- **Code splitting**: Dynamic imports for routing forms components
- **Legacy adapter**: `WithAppDirSsr.tsx` bridges App Router with legacy patterns

## Open Questions
1. Why are `apps/website`, `apps/console`, `apps/auth` referenced but not present?
2. Is there a planned separation of marketing website from main app?
3. How does the embed functionality integrate with external websites?
4. What is the migration strategy from Pages Router to App Router?