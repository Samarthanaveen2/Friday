import { lazy, Suspense, useEffect } from 'react'
import { HashRouter, Route, Routes } from 'react-router-dom'
import Nav from './components/Nav'
const Reactor = lazy(() => import('./levels/reactor'))
const Negotiator = lazy(() => import('./levels/negotiator'))
const Truth = lazy(() => import('./levels/truth'))
const Lab = lazy(() => import('./levels/lab'))
const Forge = lazy(() => import('./levels/forge'))
const Vault = lazy(() => import('./levels/vault'))

const loaders = [
  () => import('./levels/reactor'),
  () => import('./levels/negotiator'),
  () => import('./levels/truth'),
  () => import('./levels/lab'),
  () => import('./levels/forge'),
  () => import('./levels/vault'),
]

export default function App() {
  // Warm every level in the background so they are cached for offline use.
  useEffect(() => {
    const t = setTimeout(() => loaders.forEach((load) => load().catch(() => {})), 1500)
    return () => clearTimeout(t)
  }, [])

  return (
    <HashRouter>
      <div className="app">
        <Nav />
        <main className="main">
          <Suspense fallback={null}>
          <Routes>
            <Route path="/" element={<Reactor />} />
            <Route path="/negotiator/*" element={<Negotiator />} />
            <Route path="/truth/*" element={<Truth />} />
            <Route path="/lab/*" element={<Lab />} />
            <Route path="/forge/*" element={<Forge />} />
            <Route path="/vault/*" element={<Vault />} />
          </Routes>
          </Suspense>
        </main>
      </div>
    </HashRouter>
  )
}
