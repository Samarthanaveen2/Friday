import { useEffect, useMemo, useRef, useState, type PointerEvent as RPointerEvent } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../db/db'
import { CATEGORIES, CATEGORY_COLORS, findTopic } from './topics'
import { colorFor, SearchLinks, type LabEntryX } from './shared'
import { EntryCard } from './Log'

interface NodeDatum {
  name: string
  count: number
  degree: number
}
interface EdgeDatum {
  a: string
  b: string
  w: number
}
interface Body {
  x: number
  y: number
  vx: number
  vy: number
}

function buildGraph(entries: LabEntryX[]) {
  const nodes = new Map<string, NodeDatum>()
  const edges = new Map<string, EdgeDatum>()
  const neighbours = new Map<string, Set<string>>()
  for (const e of entries) {
    const ts = [...new Set(e.topics)]
    for (const t of ts) {
      const n = nodes.get(t) ?? { name: t, count: 0, degree: 0 }
      n.count++
      nodes.set(t, n)
      if (!neighbours.has(t)) neighbours.set(t, new Set())
    }
    for (let i = 0; i < ts.length; i++)
      for (let j = i + 1; j < ts.length; j++) {
        const [a, b] = ts[i] < ts[j] ? [ts[i], ts[j]] : [ts[j], ts[i]]
        const key = a + '\u0000' + b
        const ed = edges.get(key) ?? { a, b, w: 0 }
        ed.w++
        edges.set(key, ed)
        neighbours.get(a)!.add(b)
        neighbours.get(b)!.add(a)
      }
  }
  for (const [name, set] of neighbours) nodes.get(name)!.degree = set.size
  return { nodes: [...nodes.values()], edges: [...edges.values()], neighbours }
}

export default function MindMap() {
  const entries = useLiveQuery(() => db.lab.orderBy('createdAt').reverse().toArray(), []) as LabEntryX[] | undefined
  const graph = useMemo(() => buildGraph(entries ?? []), [entries])
  const [selected, setSelected] = useState<string | null>(null)
  const [hover, setHover] = useState<string | null>(null)
  const [, setFrame] = useState(0)
  const wrapRef = useRef<HTMLDivElement>(null)
  const svgRef = useRef<SVGSVGElement>(null)
  const bodies = useRef(new Map<string, Body>())
  const alpha = useRef(1)
  const raf = useRef(0)
  const drag = useRef<{ name: string; moved: boolean; sx: number; sy: number } | null>(null)
  const [size, setSize] = useState({ w: 800, h: 520 })

  // Track container size so labels stay readable on phones.
  useEffect(() => {
    const el = wrapRef.current
    if (!el) return
    const ro = new ResizeObserver(([entry]) => {
      const w = Math.max(280, Math.round(entry.contentRect.width))
      setSize({ w, h: Math.round(Math.min(560, Math.max(380, w * 0.85))) })
    })
    ro.observe(el)
    return () => ro.disconnect()
  }, [entries === undefined])

  // Seed new nodes, drop removed ones, then (re)heat the simulation.
  useEffect(() => {
    const map = bodies.current
    const names = new Set(graph.nodes.map((n) => n.name))
    for (const k of [...map.keys()]) if (!names.has(k)) map.delete(k)
    for (const n of graph.nodes) {
      if (map.has(n.name)) continue
      const nb = [...(graph.neighbours.get(n.name) ?? [])].map((x) => map.get(x)).find(Boolean)
      const angle = Math.random() * Math.PI * 2
      const r = nb ? 30 : 60 + Math.random() * 120
      const cx = nb ? nb.x : size.w / 2
      const cy = nb ? nb.y : size.h / 2
      map.set(n.name, { x: cx + Math.cos(angle) * r, y: cy + Math.sin(angle) * r, vx: 0, vy: 0 })
    }
    alpha.current = 1
    if (selected && !names.has(selected)) setSelected(null)
  }, [graph])

  // The hand-rolled force simulation.
  useEffect(() => {
    alpha.current = Math.max(alpha.current, 0.6)
    const step = () => {
      const map = bodies.current
      const list = graph.nodes.map((n) => ({ n, b: map.get(n.name)! })).filter((x) => x.b)
      const a = alpha.current
      const { w, h } = size
      const repulse = 2600 * (w < 500 ? 0.55 : 1)
      const spring = w < 500 ? 70 : 105
      // Repulsion
      for (let i = 0; i < list.length; i++) {
        const p = list[i].b
        for (let j = i + 1; j < list.length; j++) {
          const q = list[j].b
          let dx = p.x - q.x
          let dy = p.y - q.y
          let d2 = dx * dx + dy * dy
          if (d2 < 1) {
            dx = Math.random() - 0.5
            dy = Math.random() - 0.5
            d2 = 1
          }
          const f = (repulse / d2) * a
          const d = Math.sqrt(d2)
          const fx = (dx / d) * f
          const fy = (dy / d) * f
          p.vx += fx
          p.vy += fy
          q.vx -= fx
          q.vy -= fy
        }
      }
      // Springs
      for (const e of graph.edges) {
        const p = map.get(e.a)
        const q = map.get(e.b)
        if (!p || !q) continue
        const dx = q.x - p.x
        const dy = q.y - p.y
        const d = Math.sqrt(dx * dx + dy * dy) || 1
        const f = (d - spring) * 0.03 * Math.min(2, 1 + (e.w - 1) * 0.3) * a
        const fx = (dx / d) * f
        const fy = (dy / d) * f
        p.vx += fx
        p.vy += fy
        q.vx -= fx
        q.vy -= fy
      }
      // Gravity, damping, bounds (extra side room so labels aren't clipped)
      const padX = Math.min(64, Math.max(24, w * 0.14))
      for (const { n, b } of list) {
        if (drag.current?.name === n.name) {
          b.vx = b.vy = 0
          continue
        }
        b.vx += (w / 2 - b.x) * 0.006 * a
        b.vy += (h / 2 - b.y) * 0.008 * a
        b.vx *= 0.82
        b.vy *= 0.82
        b.x = Math.min(w - padX, Math.max(padX, b.x + b.vx))
        b.y = Math.min(h - 24, Math.max(24, b.y + b.vy))
      }
      alpha.current *= 0.99
      setFrame((f) => (f + 1) % 1e6)
      if (alpha.current > 0.02 || drag.current) raf.current = requestAnimationFrame(step)
    }
    raf.current = requestAnimationFrame(step)
    return () => cancelAnimationFrame(raf.current)
  }, [graph, size])

  const reheat = () => {
    if (alpha.current <= 0.02) {
      alpha.current = 0.5
      setSize((s) => ({ ...s })) // restarts the effect loop
    } else alpha.current = Math.max(alpha.current, 0.5)
  }

  const toSvg = (e: RPointerEvent) => {
    const svg = svgRef.current!
    const pt = svg.createSVGPoint()
    pt.x = e.clientX
    pt.y = e.clientY
    const m = svg.getScreenCTM()
    return m ? pt.matrixTransform(m.inverse()) : { x: 0, y: 0 }
  }

  const onNodeDown = (e: RPointerEvent, name: string) => {
    e.stopPropagation()
    ;(e.target as Element).setPointerCapture?.(e.pointerId)
    drag.current = { name, moved: false, sx: e.clientX, sy: e.clientY }
    reheat()
  }
  const onMove = (e: RPointerEvent) => {
    const d = drag.current
    if (!d) return
    if (Math.abs(e.clientX - d.sx) + Math.abs(e.clientY - d.sy) > 4) d.moved = true
    if (!d.moved) return
    const b = bodies.current.get(d.name)
    if (!b) return
    const p = toSvg(e)
    b.x = p.x
    b.y = p.y
    alpha.current = Math.max(alpha.current, 0.3)
  }
  const onUp = () => {
    const d = drag.current
    drag.current = null
    if (d && !d.moved) setSelected((s) => (s === d.name ? null : d.name))
  }

  // Stats
  const categoriesTouched = useMemo(() => {
    const s = new Set<string>()
    for (const n of graph.nodes) {
      const t = findTopic(n.name)
      if (t) s.add(t.category)
    }
    return s
  }, [graph])
  const mostConnected = useMemo(
    () => [...graph.nodes].sort((a, b) => b.degree - a.degree || b.count - a.count)[0],
    [graph],
  )

  if (!entries) return <div className="empty">Loading the map…</div>

  const focus = hover ?? selected
  const focusNb = focus ? graph.neighbours.get(focus) : undefined
  const showAllLabels = graph.nodes.length <= 36
  const selEntries = selected ? entries.filter((e) => e.topics.includes(selected)) : []
  const selTopic = selected ? findTopic(selected) : undefined

  return (
    <div className="stack">
      <div className="lab-stats">
        <div className="panel lab-stat">
          <div className="panel-title">Topics explored</div>
          <div className="big-number">{graph.nodes.length}</div>
        </div>
        <div className="panel lab-stat">
          <div className="panel-title">Categories touched</div>
          <div className="big-number">
            {categoriesTouched.size}
            <span className="muted lab-stat-of">/{CATEGORIES.length}</span>
          </div>
        </div>
        <div className="panel lab-stat">
          <div className="panel-title">Most connected</div>
          {mostConnected ? (
            <button className="lab-stat-topic" style={{ color: colorFor(mostConnected.name) }} onClick={() => setSelected(mostConnected.name)}>
              {mostConnected.name}
              <span className="lab-stat-sub">{mostConnected.degree} link{mostConnected.degree === 1 ? '' : 's'}</span>
            </button>
          ) : (
            <div className="muted">—</div>
          )}
        </div>
      </div>

      <div className="panel lab-map-panel">
        <div className="row-between" style={{ marginBottom: 8 }}>
          <div className="panel-title" style={{ margin: 0 }}>
            Mind map
          </div>
          <span className="muted small">Tap a topic, or drag to rearrange</span>
        </div>
        <div ref={wrapRef} className="lab-map-wrap">
          {graph.nodes.length === 0 ? (
            <div className="lab-map-empty">Your mind map is empty. Save a collision to see it start to grow.</div>
          ) : (
            <svg
              ref={svgRef}
              className="lab-map"
              viewBox={`0 0 ${size.w} ${size.h}`}
              width={size.w}
              height={size.h}
              onPointerMove={onMove}
              onPointerUp={onUp}
              onPointerLeave={() => (drag.current = null)}
              onClick={(e) => e.target === e.currentTarget && setSelected(null)}
            >
              <g>
                {graph.edges.map((e) => {
                  const p = bodies.current.get(e.a)
                  const q = bodies.current.get(e.b)
                  if (!p || !q) return null
                  const lit = focus && (e.a === focus || e.b === focus)
                  const dim = focus && !lit
                  return (
                    <line
                      key={e.a + '|' + e.b}
                      x1={p.x}
                      y1={p.y}
                      x2={q.x}
                      y2={q.y}
                      style={{ stroke: lit ? colorFor(focus!) : 'var(--faint)' }}
                      strokeOpacity={dim ? 0.2 : lit ? 0.9 : 1}
                      strokeWidth={Math.min(2.5, 1 + (e.w - 1) * 0.5)}
                    />
                  )
                })}
              </g>
              <g>
                {graph.nodes.map((n) => {
                  const b = bodies.current.get(n.name)
                  if (!b) return null
                  const r = 4 + Math.min(7, n.degree + n.count * 0.5)
                  const c = colorFor(n.name)
                  const isFocus = focus === n.name
                  const dim = focus && !isFocus && !focusNb?.has(n.name)
                  const label = showAllLabels || isFocus || focusNb?.has(n.name) || n.degree >= 3
                  return (
                    <g
                      key={n.name}
                      className="lab-node"
                      transform={`translate(${b.x},${b.y})`}
                      opacity={dim ? 0.3 : 1}
                      onPointerDown={(e) => onNodeDown(e, n.name)}
                      onPointerEnter={() => setHover(n.name)}
                      onPointerLeave={() => setHover(null)}
                    >
                      <circle r={r + 10} fill="transparent" />
                      {selected === n.name && <circle r={r + 4} fill="none" style={{ stroke: c }} strokeWidth={1.5} strokeOpacity={0.5} />}
                      <circle r={r} style={{ fill: c }} className="lab-node-dot" />
                      {label && (
                        <text y={r + 14} textAnchor="middle" className={`lab-node-label${isFocus ? ' focus' : ''}`}>
                          {n.name.length > 26 ? n.name.slice(0, 24) + '…' : n.name}
                        </text>
                      )}
                    </g>
                  )
                })}
              </g>
            </svg>
          )}
        </div>
        {categoriesTouched.size > 0 && (
          <div className="lab-legend">
            {CATEGORIES.filter((c) => categoriesTouched.has(c)).map((c) => (
              <span key={c} className="lab-legend-item">
                <i style={{ background: CATEGORY_COLORS[c] }} /> {c}
              </span>
            ))}
          </div>
        )}
      </div>

      {selected && (
        <section className="panel stack lab-node-detail" style={{ ['--c' as string]: colorFor(selected) }}>
          <div className="row-between">
            <div>
              <div className="lab-eyebrow" style={{ color: colorFor(selected) }}>
                {selTopic?.category ?? 'Topic'}
              </div>
              <h3 className="lab-node-title">{selected}</h3>
            </div>
            <button className="btn btn-ghost btn-sm" onClick={() => setSelected(null)}>
              Close
            </button>
          </div>
          {selTopic && <p className="lab-node-hook">{selTopic.hook}</p>}
          <SearchLinks query={selected} compact />
          {graph.neighbours.get(selected)?.size ? (
            <div className="muted small">
              Paired with{' '}
              {[...graph.neighbours.get(selected)!].map((n, i) => (
                <span key={n}>
                  {i > 0 && ', '}
                  <button className="lab-inline-link" style={{ color: colorFor(n) }} onClick={() => setSelected(n)}>
                    {n}
                  </button>
                </span>
              ))}
            </div>
          ) : null}
          <div className="lab-list lab-list-inset">
            {selEntries.map((e) => (
              <EntryCard key={e.id} entry={e} onTopic={setSelected} />
            ))}
          </div>
        </section>
      )}
    </div>
  )
}
