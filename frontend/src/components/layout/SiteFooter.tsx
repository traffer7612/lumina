import { Link } from 'react-router-dom';
import { Shield, ExternalLink } from 'lucide-react';
import {
  DOCS_TREE_URL,
  DOC_TOKENOMICS_CHECKLIST_URL,
  DOC_PRODUCTION_ADDRESSES_URL,
  REPO_ROOT_URL,
} from '../../lib/publicDocs';

/** Ceitnot lending / CDP UI; not affiliated with unrelated third-party products. */
export default function SiteFooter() {
  return (
    <footer className="mt-auto border-t border-ceitnot-border/80 bg-ceitnot-bg/60">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-12">
        <div className="relative overflow-hidden rounded-2xl border border-ceitnot-border bg-gradient-to-br from-ceitnot-surface via-ceitnot-surface to-ceitnot-bg/90 p-6 sm:p-8 shadow-[0_0_40px_-12px_rgba(212,168,83,0.15)]">
          <div className="pointer-events-none absolute -right-8 -top-8 h-32 w-32 rounded-full bg-ceitnot-accent/10 blur-2xl" />
          <div className="pointer-events-none absolute -bottom-6 -left-6 h-24 w-24 rounded-full bg-ceitnot-gold/5 blur-2xl" />

          <div className="relative flex flex-col sm:flex-row sm:items-start gap-5">
            <div className="shrink-0 flex h-11 w-11 items-center justify-center rounded-xl bg-ceitnot-gold/12 ring-1 ring-ceitnot-gold/20">
              <Shield className="h-5 w-5 text-ceitnot-gold" aria-hidden />
            </div>
            <div className="min-w-0 space-y-3">
              <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-ceitnot-gold/85">
                Independent protocol
              </p>
              <p className="text-sm sm:text-[15px] text-ceitnot-muted-2 leading-relaxed">
                <span className="text-white/90 font-medium">Ceitnot</span> — lending and CDP on
                Ethereum-compatible networks. This interface and repository are{' '}
                <span className="text-white/95">not affiliated</span> with unrelated third-party protocols
                or teams unless explicitly stated.
              </p>
              <p className="text-xs text-ceitnot-muted leading-relaxed border-l-2 border-ceitnot-gold/25 pl-3">
                Ceitnot — независимый кредитный протокол на EVM. Не связан со сторонними проектами, если не
                указано иное.
              </p>
            </div>
          </div>
        </div>

        <nav
          className="mt-8 flex flex-wrap items-center justify-center gap-x-8 gap-y-3 text-sm text-ceitnot-muted"
          aria-label="Footer"
        >
          <Link to="/security" className="hover:text-ceitnot-gold transition-colors">
            Security
          </Link>
          <a
            href={DOCS_TREE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 hover:text-ceitnot-gold transition-colors"
          >
            Docs
            <ExternalLink size={12} className="opacity-70" aria-hidden />
          </a>
          <a
            href={DOC_TOKENOMICS_CHECKLIST_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 hover:text-ceitnot-gold transition-colors"
          >
            Go-live checklist
            <ExternalLink size={12} className="opacity-70" aria-hidden />
          </a>
          <a
            href={DOC_PRODUCTION_ADDRESSES_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 hover:text-ceitnot-gold transition-colors"
          >
            Contract addresses
            <ExternalLink size={12} className="opacity-70" aria-hidden />
          </a>
          <a
            href={REPO_ROOT_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 hover:text-ceitnot-gold transition-colors"
          >
            GitHub
            <ExternalLink size={12} className="opacity-70" aria-hidden />
          </a>
        </nav>
      </div>
    </footer>
  );
}
