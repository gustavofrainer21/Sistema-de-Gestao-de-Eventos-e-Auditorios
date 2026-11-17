import { FormEvent, useState } from 'react'
import { api, mensagemDeErro } from '../api'
import type { Bloqueio, Local } from '../types'
import { Alerta, fmtData, paraIso, useCarregar } from '../util'

/** RF02 (locais e bloqueios) e RF03 (disponibilidade). */
export default function AdminLocais() {
  const locais = useCarregar(() => api.get<Local[]>('/api/locais'), [])
  const [erro, setErro] = useState<string | null>(null)

  // cadastro / edição
  const [editando, setEditando] = useState<string | null>(null)
  const [nome, setNome] = useState('')
  const [capacidade, setCapacidade] = useState(50)
  const [localizacao, setLocalizacao] = useState('')

  // disponibilidade
  const [dIni, setDIni] = useState('')
  const [dFim, setDFim] = useState('')
  const [dCap, setDCap] = useState(1)
  const [disponiveis, setDisponiveis] = useState<Local[] | null>(null)

  // bloqueios
  const [localSel, setLocalSel] = useState<string>('')
  const bloqueios = useCarregar(
    () => (localSel ? api.get<Bloqueio[]>(`/api/locais/${localSel}/bloqueios`) : Promise.resolve([] as Bloqueio[])),
    [localSel],
  )
  const [bIni, setBIni] = useState('')
  const [bFim, setBFim] = useState('')
  const [bMotivo, setBMotivo] = useState('')

  function limpar() {
    setEditando(null)
    setNome('')
    setCapacidade(50)
    setLocalizacao('')
  }

  async function salvar(ev: FormEvent) {
    ev.preventDefault()
    setErro(null)
    try {
      const corpo = { nome, capacidade, localizacao }
      if (editando) await api.put(`/api/locais/${editando}`, corpo)
      else await api.post('/api/locais', corpo)
      limpar()
      locais.recarregar()
    } catch (e) {
      setErro(mensagemDeErro(e))
    }
  }

  async function alternar(l: Local) {
    setErro(null)
    try {
      await api.patch(`/api/locais/${l.id}/ativo?valor=${!l.ativo}`)
      locais.recarregar()
    } catch (e) {
      setErro(mensagemDeErro(e))
    }
  }

  async function consultar(ev: FormEvent) {
    ev.preventDefault()
    setErro(null)
    try {
      const qs = new URLSearchParams({ inicio: paraIso(dIni), fim: paraIso(dFim), capacidade: String(dCap) })
      setDisponiveis(await api.get<Local[]>(`/api/locais/disponiveis?${qs}`))
    } catch (e) {
      setErro(mensagemDeErro(e))
    }
  }

  async function bloquear(ev: FormEvent) {
    ev.preventDefault()
    setErro(null)
    try {
      await api.post(`/api/locais/${localSel}/bloqueios`, {
        inicio: paraIso(bIni),
        fim: paraIso(bFim),
        motivo: bMotivo || null,
      })
      setBIni('')
      setBFim('')
      setBMotivo('')
      bloqueios.recarregar()
    } catch (e) {
      setErro(mensagemDeErro(e))
    }
  }

  async function removerBloqueio(id: string) {
    setErro(null)
    try {
      await api.del(`/api/locais/bloqueios/${id}`)
      bloqueios.recarregar()
    } catch (e) {
      setErro(mensagemDeErro(e))
    }
  }

  return (
    <>
      <h1>Locais e auditórios</h1>
      {erro && <Alerta tipo="erro">{erro}</Alerta>}
      {locais.erro && <Alerta tipo="erro">{locais.erro}</Alerta>}

      <div className="tabela-wrap">
        <table>
          <thead>
            <tr><th>Nome</th><th>Capacidade</th><th>Localização</th><th>Situação</th><th></th></tr>
          </thead>
          <tbody>
            {locais.dados?.map((l) => (
              <tr key={l.id}>
                <td>{l.nome}</td>
                <td>{l.capacidade}</td>
                <td>{l.localizacao}</td>
                <td>{l.ativo ? 'Ativo' : 'Desativado'}</td>
                <td className="acoes">
                  <button className="link" onClick={() => { setEditando(l.id); setNome(l.nome); setCapacidade(l.capacidade); setLocalizacao(l.localizacao) }}>Editar</button>
                  <button className="link" onClick={() => alternar(l)}>{l.ativo ? 'Desativar' : 'Reativar'}</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <form className="formulario" onSubmit={salvar}>
        <h2>{editando ? 'Editar local' : 'Novo local'}</h2>
        <label>Nome<input required value={nome} onChange={(e) => setNome(e.target.value)} /></label>
        <label>Capacidade<input type="number" min={1} required value={capacidade} onChange={(e) => setCapacidade(Number(e.target.value))} /></label>
        <label>Localização<input required value={localizacao} onChange={(e) => setLocalizacao(e.target.value)} /></label>
        <div className="acoes">
          <button className="botao" type="submit">Salvar</button>
          {editando && <button className="botao secundario" type="button" onClick={limpar}>Cancelar edição</button>}
        </div>
      </form>

      <form className="formulario" onSubmit={consultar}>
        <h2>Consultar disponibilidade</h2>
        <label>Início<input type="datetime-local" required value={dIni} onChange={(e) => setDIni(e.target.value)} /></label>
        <label>Término<input type="datetime-local" required value={dFim} onChange={(e) => setDFim(e.target.value)} /></label>
        <label>Capacidade mínima<input type="number" min={1} value={dCap} onChange={(e) => setDCap(Number(e.target.value))} /></label>
        <button className="botao" type="submit">Consultar</button>
        {disponiveis && (
          disponiveis.length === 0
            ? <Alerta tipo="erro">Nenhum local disponível para os critérios informados.</Alerta>
            : <ul className="lista">{disponiveis.map((l) => <li key={l.id}>{l.nome} · {l.capacidade} lugares · {l.localizacao}</li>)}</ul>
        )}
      </form>

      <section className="formulario">
        <h2>Bloqueios de agenda</h2>
        <label>Local
          <select value={localSel} onChange={(e) => setLocalSel(e.target.value)}>
            <option value="">Selecione…</option>
            {locais.dados?.map((l) => <option key={l.id} value={l.id}>{l.nome}</option>)}
          </select>
        </label>
        {localSel && (
          <>
            <ul className="lista">
              {bloqueios.dados?.map((b) => (
                <li key={b.id}>
                  {fmtData(b.inicio)} → {fmtData(b.fim)} {b.motivo && `· ${b.motivo}`}{' '}
                  <button className="link" onClick={() => removerBloqueio(b.id)}>Remover</button>
                </li>
              ))}
              {bloqueios.dados?.length === 0 && <li className="muted">Nenhum bloqueio.</li>}
            </ul>
            <form onSubmit={bloquear} className="formulario interno">
              <label>Início<input type="datetime-local" required value={bIni} onChange={(e) => setBIni(e.target.value)} /></label>
              <label>Término<input type="datetime-local" required value={bFim} onChange={(e) => setBFim(e.target.value)} /></label>
              <label>Motivo<input value={bMotivo} onChange={(e) => setBMotivo(e.target.value)} /></label>
              <button className="botao" type="submit">Bloquear período</button>
            </form>
          </>
        )}
      </section>
    </>
  )
}
