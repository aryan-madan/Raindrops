import { GithubLogo, AppWindow } from '@phosphor-icons/react'

export default function Footer() {
  return (
    <footer className="relative py-12 md:py-20 mt-8 md:mt-20 flex flex-col items-center justify-center overflow-hidden">
        
        <div className="flex items-center gap-6 z-10 mb-20 md:mb-40">
            <a href="https://github.com/aryan-madan/Raindrops" target="_blank" rel="noreferrer" className="p-4 rounded-2xl bg-surface text-primary hover:scale-110 hover:bg-primary hover:text-background transition-all duration-300 shadow-sm">
                <GithubLogo size={24} weight="fill" />
            </a>
            <a href="https://github.com/aryan-madan/Raindrops/releases/" target="_blank" rel="noreferrer" className="p-4 rounded-2xl bg-surface text-primary hover:scale-110 hover:bg-primary hover:text-background transition-all duration-300 shadow-sm">
                <AppWindow size={24} weight="fill" />
            </a>
        </div>
        
        <div className="absolute bottom-[-2%] md:bottom-[-6%] left-1/2 -translate-x-1/2 w-full select-none pointer-events-none flex justify-center">
            <h1 className="text-[22vw] md:text-[18vw] font-bold tracking-tighter text-surface dark:text-white/5 leading-none whitespace-nowrap transition-colors">
                Raindrops
            </h1>
        </div>
    </footer>
  )
}