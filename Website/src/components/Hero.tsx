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
        duration: 1.5,
        stagger: 0.1,
      }, "-=1.4")
      .from(".hero-image", {
        y: 200,
        scale: 0.9,
        opacity: 0,
        duration: 2.0,
        ease: "elastic.out(1, 0.6)"
      }, "-=1.6")
      
    }, comp)

    return () => ctx.revert()
  }, [])

  return (
    <section ref={comp} className="pt-48 pb-24 px-6 flex flex-col items-center w-full max-w-[1200px] mx-auto">
      
      <div className="text-center relative z-10 mb-16">
        <h1 className="text-6xl md:text-8xl lg:text-[7.5rem] font-bold tracking-tighter text-primary leading-[0.9] mb-4">
          <div className="overflow-hidden py-4 -my-2"><div className="hero-line block">Break the</div></div>
          <div className="overflow-hidden py-4 -my-4 flex justify-center gap-[0.2em] flex-wrap">
            <div className="hero-line block">walled</div> 
            <div className="hero-line block relative z-10">
                garden
                <div className="absolute bottom-[0.1em] left-[-0.05em] right-[-0.05em] h-[0.35em] bg-accent/40 -z-10 rounded-sm"></div>
            </div>
          </div>
        </h1>
      </div>

      <div className="hero-actions flex flex-col items-center gap-10 mb-28">
        <div className="flex flex-wrap items-center justify-center gap-6 md:gap-12">
            <a href="https://github.com/aryan-madan/Raindrops/releases/" target="_blank" rel="noreferrer" className="bg-primary hover:scale-105 active:scale-95 text-background px-8 py-4 rounded-2xl font-bold text-lg transition-transform duration-300 ease-in-out flex items-center gap-3 shadow-2xl shadow-primary/20">
                <GithubLogo weight="fill" size={24} />
                <span>Download on GitHub</span>
            </a>

            <a href="https://hackclub.com" target="_blank" rel="noreferrer" className="flex items-center gap-4 opacity-60 grayscale hover:grayscale-0 transition-all duration-300 ease-in-out cursor-pointer group">
                <img src="https://assets.hackclub.com/flag-standalone-wtransparent.svg" alt="Hack Club Flag" className="w-12 h-12 object-contain group-hover:-rotate-12 transition-transform duration-300 ease-in-out" />
                <div className="text-xs font-semibold leading-tight text-secondary text-left">
                    Built with<br/>
                    <span className="text-sm font-bold text-primary font-sans">Hack Club</span>
                </div>
            </a>
        </div>
      </div>

      <div className="hero-image w-full">
          <img 
              src="/app.png" 
              alt="Raindrops Screenshot" 
              className="w-full h-auto rounded-[2rem] hover:scale-[1.01] transition-transform duration-500"
          />
      </div>
    </section>
  )
}