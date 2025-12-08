import Navbar from './components/Navbar'
import Hero from './components/Hero'
import Features from './components/Features'
import Footer from './components/Footer'

function App() {
  return (
    <div className="flex flex-col min-h-screen bg-background text-primary font-sans selection:bg-accent selection:text-white overflow-hidden">
      <Navbar />
      <Hero />
      <Features />
      <Footer />
    </div>
  )
}

export default App