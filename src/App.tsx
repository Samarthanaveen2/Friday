import { HashRouter, Route, Routes } from 'react-router-dom'
import Attic from './attic'

export default function App() {
  return (
    <HashRouter>
      <main className="main">
        <Routes>
          <Route path="/*" element={<Attic />} />
        </Routes>
      </main>
    </HashRouter>
  )
}
