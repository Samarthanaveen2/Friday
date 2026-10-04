import { HashRouter, Route, Routes } from 'react-router-dom'
import Nav from './components/Nav'
import Reactor from './levels/reactor'
import Negotiator from './levels/negotiator'
import Truth from './levels/truth'
import Lab from './levels/lab'
import Forge from './levels/forge'
import Vault from './levels/vault'

export default function App() {
  return (
    <HashRouter>
      <div className="app">
        <Nav />
        <main className="main">
          <Routes>
            <Route path="/" element={<Reactor />} />
            <Route path="/negotiator/*" element={<Negotiator />} />
            <Route path="/truth/*" element={<Truth />} />
            <Route path="/lab/*" element={<Lab />} />
            <Route path="/forge/*" element={<Forge />} />
            <Route path="/vault/*" element={<Vault />} />
          </Routes>
        </main>
      </div>
    </HashRouter>
  )
}
