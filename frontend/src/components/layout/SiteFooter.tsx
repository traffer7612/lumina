import { Link } from 'react-router-dom';
import { Shield, ExternalLink } from 'lucide-react';
import {
  DOCS_TREE_URL,
  DOC_TOKENOMICS_CHECKLIST_URL,
  DOC_PRODUCTION_ADDRESSES_URL,
  REPO_ROOT_URL,
} from '../../lib/publicDocs';

/**
 * Brand clarity: this app is Lumina lending on EVM, not LuminaDEX (Mina) or other "Lumina" products.
 */
export default function SiteFooter() {
  return (
    <footer className="mt-auto border-t border-aura-border/80 bg-aura-bg/60">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-12">
        <div className="relative overflow-hidden rounded-2xl border border-aura-border bg-gradient-to-br from-aura-surface via-aura-surface to-aura-bg/90 p-6 sm:p-8 shadow-[0_0_40px_-12px_rgba(212,168,83,0.15)]">
          <div className="pointer-events-none absolute -right-8 -top-8 h-32 w-32 rounded-full bg-aura-accent/10 blur-2xl" />
          <div className="pointer-events-none absolute -bottom-6 -left-6 h-24 w-24 rounded-full bg-aura-gold/5 blur-2xl" />

          <div className="relative flex flex-col sm:flex-row sm:items-start gap-5">
            <div className="shrink-0 flex h-11 w-11 items-center justify-center rounded-xl bg-aura-gold/12 ring-1 ring-aura-gold/20">
              <Shield className="h-5 w-5 text-aura-gold" aria-hidden />
            </div>
            <div className="min-w-0 space-y-3">
              <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-aura-gold/85">
                Independent protocol
              </p>
              <p className="text-sm sm:text-[15px] text-aura-muted-2 leading-relaxed">
                <span className="text-white/90 font-medium">Lumina Protocol</span> — lending and CDP on
                Ethereum-compatible networks. This project is{' '}
                <span className="text-white/95">not affiliated</span> with{' '}
                <span className="text-white/90">LuminaDEX</span>, the Mina ecosystem DEX, or any other team
                using the name &quot;Lumina&quot;. Separate codebases, separate products.
              </p>
              <p className="text-xs text-aura-muted leading-relaxed border-l-2 border-aura-gold/25 pl-3">
                Lumina Protocol — независимый кредитный протокол на EVM. Не связан с LuminaDEX (Mina) и
                другими проектами с похожим названием.
              </p>
            </div>
          </div>
        </div>

        <nav
          className="mt-8 flex flex-wrap items-center justify-center gap-x-8 gap-y-3 text-sm text-aura-muted"
          aria-label="Footer"
        >
          <Link to="/security" className="hover:text-aura-gold transition-colors">
            Security
          </Link>
          <a
            href={DOCS_TREE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 hover:text-aura-gold transition-colors"
          >
            Docs
            <ExternalLink size={12} className="opacity-70" aria-hidden />
          </a>
          <a
            href={DOC_TOKENOMICS_CHECKLIST_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 hover:text-aura-gold transition-colors"
          >
            Go-live checklist
            <ExternalLink size={12} className="opacity-70" aria-hidden />
          </a>
          <a
            href={DOC_PRODUCTION_ADDRESSES_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 hover:text-aura-gold transition-colors"
          >
            Contract addresses
            <ExternalLink size={12} className="opacity-70" aria-hidden />
          </a>
          <a
            href={REPO_ROOT_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 hover:text-aura-gold transition-colors"
          >
            GitHub
            <ExternalLink size={12} className="opacity-70" aria-hidden />
          </a>
        </nav>
      </div>
    </footer>
  );
}
