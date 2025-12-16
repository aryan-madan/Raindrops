import { useRef, useLayoutEffect } from 'react'
import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'
import { SpeakerHigh, Waveform, Lightning, ArrowsDownUp, DiceFive, PlusSquare, AppWindow, PaperPlaneTilt, GithubLogo } from '@phosphor-icons/react'

gsap.registerPlugin(ScrollTrigger)

const features = [
    {
        icon: <PaperPlaneTilt size={48} weight="regular" />,
        title: "High fidelity\ntransfer",
    },
    {
        icon: <Waveform size={48} weight="regular" />,
        title: "Immersive\nanimations",
    },
    {
        icon: <Lightning size={48} weight="regular" />,
        title: "Instant local\nfeedback",
    },
    {
        icon: <ArrowsDownUp size={48} weight="regular" />,
        title: "Up/down\nuploads",
    },
    {
        icon: <DiceFive size={48} weight="regular" />,
        title: "Randomized\nPIN security",
    },
    {
        icon: <PlusSquare size={48} weight="regular" />,
        title: "Customizable\nsettings",
    },
    {
        icon: <AppWindow size={48} weight="regular" />,
        title: "Menubar\napplication",
    },
    {
        icon: <SpeakerHigh size={48} weight="fill" />,
        title: "Blazing fast\nnative app",
    }
]

export default function Features() {
    const comp = useRef(null)

    useLayoutEffect(() => {
        let ctx = gsap.context(() => {
        gsap.from(".feat-item", {
            scrollTrigger: {
                trigger: ".features-container",
                start: "top 85%",
            },
            y: 80,
            opacity: 0,
            scale: 0.8,
            filter: "blur(10px)",
            duration: 1.6,
            stagger: 0.1,
            ease: "elastic.out(1, 0.75)"
        })
        }, comp)
        return () => ctx.revert()
    }, [])

    return (
        <section ref={comp} className="py-24 md:py-32 px-6 md:px-6 w-full max-w-[1200px] mx-auto">
            <div className="features-container grid grid-cols-1 md:grid-cols-4 gap-x-4 md:gap-x-6 gap-y-24 md:gap-y-24">
                {features.map((f, i) => (
                    <div key={i} className="feat-item flex flex-col items-center text-center group cursor-default">
                        <div className="mb-8 md:mb-8 text-primary group-hover:scale-110 group-hover:-rotate-3 transition-transform duration-500 ease-in-out p-6 md:p-4 bg-surface rounded-[2.5rem] md:rounded-3xl shadow-sm dark:shadow-none">
                            <div className="scale-150 md:scale-100">{f.icon}</div>
                        </div>
                        <h3 className="text-4xl md:text-xl font-bold text-primary leading-[1.1] md:leading-tight whitespace-pre-line relative z-10">
                            {f.title}
                            {/* @ts-ignore */}
                            {f.highlight && (
                                <div className="absolute bottom-[-0.1em] left-[-0.2em] right-[-0.2em] h-[0.4em] bg-accent/40 rounded-sm -z-10 rotate-1"></div>
                            )}
                        </h3>
                    </div>
                ))}
            </div>
            
            <div className="mt-32 md:mt-40 flex justify-center w-full px-4">
                <a href="https://github.com/aryan-madan/Raindrops/releases/" target="_blank" rel="noreferrer" className="w-full md:w-auto justify-center bg-primary hover:scale-105 active:scale-95 text-background px-6 py-4 md:px-8 md:py-4 rounded-2xl font-bold text-lg md:text-lg transition-transform duration-300 ease-in-out flex items-center gap-3 shadow-xl shadow-primary/20">
                    <GithubLogo weight="fill" size={24} className="md:w-6 md:h-6" />
                    <span>Download on GitHub</span>
                </a>
            </div>
        </section>
    )
}
