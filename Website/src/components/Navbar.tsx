import { GithubLogo } from '@phosphor-icons/react'

export default function Navbar() {
  return (
    <>
      <div className="fixed top-0 left-0 right-0 h-24 md:h-32 bg-gradient-to-b from-background to-transparent z-40 pointer-events-none transition-colors duration-500" />
      <nav className="fixed top-0 left-0 right-0 z-50 px-6 py-6 md:px-5 md:py-6 w-full max-w-[1200px] mx-auto flex justify-between items-center pointer-events-none">
        <div className="pointer-events-auto flex items-center gap-2.5 md:gap-3">
          <div className="w-10 h-10 md:w-10 md:h-10 bg-primary text-background rounded-xl flex items-center justify-center transition-colors">
              <div 
                  className="w-6 h-6 md:w-6 md:h-6 bg-background" 
                  style={{ 
                      maskImage: 'url(/favicon.svg)', 
                      maskSize: 'contain', 
                      maskPosition: 'center', 
                      maskRepeat: 'no-repeat',
                      WebkitMaskImage: 'url(/favicon.svg)', 
                      WebkitMaskSize: 'contain', 
                      WebkitMaskPosition: 'center', 
                      WebkitMaskRepeat: 'no-repeat'
                  }}
              />
          </div>
          <span className="font-bold text-xl md:text-xl tracking-tight text-primary transition-colors">Raindrops</span>
          <span className="bg-surface border border-primary/10 text-secondary text-[10px] font-bold px-1.5 py-0.5 rounded-md transition-colors">v1.3.2</span>
        </div>

        <div className="pointer-events-auto flex items-center gap-4 md:gap-6">
          <a href="https://github.com/aryan-madan/Raindrops" target="_blank" rel="noreferrer" className="bg-primary hover:opacity-90 text-background px-3.5 py-2.5 md:px-5 md:py-2.5 rounded-xl font-semibold text-sm md:text-sm transition-all flex items-center gap-2 shadow-lg shadow-black/5 dark:shadow-white/5">
              <GithubLogo weight="fill" size={20} className="md:w-[18px] md:h-[18px]" />
              <span className="hidden md:inline">GitHub</span>
              <span className="opacity-40 hidden md:inline">→</span>
          </a>
        </div>
      </nav>
    </>
  )
}
