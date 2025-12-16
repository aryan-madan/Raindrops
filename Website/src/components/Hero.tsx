import { useRef, useLayoutEffect } from 'react'
import gsap from 'gsap'
import { GithubLogo } from '@phosphor-icons/react'

export default function Hero() {
  const comp = useRef(null)

  useLayoutEffect(() => {
    let ctx = gsap.context(() => {
      const tl = gsap.timeline({ defaults: { ease: "elastic.out(1, 0.75)" } })
      
      tl.from(".hero-line", {
        y: 120,
        opacity: 0,
        filter: "blur(12px)",
        duration: 1.8,
        stagger: 0.1,
        rotationX: -40,
        transformOrigin: "bottom center",
        ease: "back.out(1.7)"
      })
      .from(".hero-actions > *", {
        scale: 0.8,
        y: 60,
        opacity: 0,
        filter: "blur(10px)",
        duration: 1.5,
        stagger: 0.1,
      }, "-=1.4")
      .from(".hero-image", {
        y: 200,
        scale: 0.9,
        opacity: 0,
        filter: "blur(10px)",
        duration: 2.0,
        ease: "elastic.out(1, 0.6)"
      }, "-=1.6")
      
    }, comp)

    return () => ctx.revert()
  }, [])

  return (
    <section ref={comp} className="pt-32 md:pt-48 pb-10 md:pb-24 px-6 md:px-6 flex flex-col items-start md:items-center w-full max-w-[1200px] mx-auto overflow-hidden">
      
      <div className="text-left md:text-center relative z-10 mb-12 md:mb-16 w-full">
        <h1 className="text-7xl sm:text-7xl md:text-8xl lg:text-[7.5rem] font-bold tracking-tighter text-primary leading-[0.9] mb-6 md:mb-4">
          <div className="overflow-hidden py-1 -my-1 md:py-4 md:-my-2"><div className="hero-line block">Break the</div></div>
          <div className="overflow-hidden py-1 -my-1 md:py-4 md:-my-4 flex flex-wrap justify-start md:justify-center gap-[0.2em]">
            <div className="hero-line block">walled</div> 
            <div className="hero-line block relative z-10">
                garden
                <div className="absolute bottom-[0.1em] left-[-0.05em] right-[-0.05em] h-[0.35em] bg-accent/40 -z-10 rounded-sm"></div>
            </div>
          </div>
        </h1>
      </div>

      <div className="hero-actions flex flex-col items-start md:items-center gap-8 md:gap-10 mb-16 md:mb-28 w-full max-w-sm md:max-w-none">
        <div className="flex flex-col md:flex-row items-start md:items-center justify-start md:justify-center gap-8 md:gap-12 w-full">
            <a href="https://github.com/aryan-madan/Raindrops/releases/" target="_blank" rel="noreferrer" className="w-full md:w-auto justify-center bg-primary hover:scale-105 active:scale-95 text-background px-6 py-4 md:px-8 md:py-4 rounded-2xl font-bold text-lg md:text-lg transition-transform duration-300 ease-in-out flex items-center gap-3 shadow-2xl shadow-primary/20">
                <GithubLogo weight="fill" size={24} className="md:w-6 md:h-6" />
                <span>Download on GitHub</span>
            </a>

            <a href="https://hackclub.com" target="_blank" rel="noreferrer" className="flex items-center gap-4 opacity-80 hover:opacity-100 transition-all duration-300 ease-in-out cursor-pointer group pl-1 md:pl-0">
                <img 
                  src="https://assets.hackclub.com/flag-standalone-wtransparent.svg" 
                  alt="Hack Club Flag" 
                  className="w-12 h-12 md:w-12 md:h-12 object-contain group-hover:-rotate-12 transition-transform duration-300 ease-in-out brightness-0 dark:invert" 
                />
                <div className="text-sm font-semibold leading-tight text-secondary text-left group-hover:text-primary transition-colors">
                    Built with<br/>
                    <span className="text-base font-bold text-primary font-sans">Hack Club</span>
                </div>
            </a>
        </div>
      </div>

      <div className="hero-image w-full">
          <img 
              src="/app.png" 
              alt="Raindrops Screenshot" 
              className="w-full h-auto rounded-[1.5rem] md:rounded-[2rem] hover:scale-[1.01] transition-transform duration-500"
          />
      </div>
    </section>
  )
}
