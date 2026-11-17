import { FormEvent, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api, mensagemDeErro } from '../api'
import type { CheckinResultado, Detalhe, Inscrito } from '../types'
import { Alerta, Badge, fmtData, useCarregar } from '../util'

/** RF09 check-in + RF11 ajustes administrativos (vagas, encerramento) e lista de inscritos. */
export default function Checkin() {
  const { id } = useParams()
  const evento = useCarregar(() => api.get<Detalhe>(`/api/eventos/${id}`), [id])
  const inscritos = useCarregar(() => api.get<Inscrito[]>(`/api/eventos/${id}/inscritos`), [id])

  const [codigo, setCodigo] = useState('')
  const [resultado, setResultado] = useState<{ ok: boolean; texto: string } | null>(null)
  const [novasVagas, setNovasVagas] = useState<number | ''>('')
  const [erro, setErro] = useState<string | null>(null)

  async function validar(ev: FormEvent) {
    ev.preventDefault()
    setResultado(null)
    try {
      const r = await api.post<CheckinResultado>(`/api/eventos/${id}/checkin`, { codigo })
      setResultado({ ok: true, texto: `Check-in ACEITO: ${r.participante} às ${fmtData(r.registradoEm)}` })
      setCodigo('')
      inscritos.recarregar()
    } catch (e) {
      setResultado({ ok: false, texto: `Check-in REJEITADO: ${mensagemDeErro(e)}` })
    }
  }

  async function ajustarVagas(ev: FormEvent) {
    ev.preventDefault()
    if (novasVagas === '') return
    setErro(null)
    try {
      await api.patch(`/api/eventos/${id}/vagas`, { vagas: novasVagas })
      setNovasVagas('')
      evento.recarregar()
      inscritos.recarregar()
    } catch (e) {
      setErro(mensagemDeErro(e))
    }
  }

  async function encerrar() {
    if (!window.confirm('Encerrar este evento? Novas inscrições serão bloqueadas.')) return
    setErro(null)
    try {
      await api.post(`/api/eventos/${id}/encerrar`)
      evento.recarregar()
    } catch (e) {
      setErro(mensagemDeErro(e))
    }
  }

  const e = evento.dados?.evento

  return (
    <>
      <p><Link to="/admin">← Painel</Link></p>
      {evento.erro && <Alerta tipo="erro">{evento.erro}</Alerta>}
      {e && (
        <>
          <div className="linha">
            <h1>{e.titulo}</h1>
            <Badge valor={e.estado} />
          </div>
          <p className="muted">
            {fmtData(e.inicio)} · {e.localNome} · {e.confirmados}/{e.vagas} confirmados · {e.emEspera} na fila
          </p>
        </>
      )}
      {erro && <Alerta tipo="erro">{erro}</Alerta>}

      <form className="formulario" onSubmit={validar}>
        <h2>Validar check-in</h2>
        <label>Código do participante (QR Code ou chip do crachá)
          <input required autoFocus value={codigo} onChange={(e2) => setCodigo(e2.target.value)} placeholder="cole ou leia o código" />
        </label>
        <button className="botao" type="submit">Validar</button>
        {resultado && <Alerta tipo={resultado.ok ? 'ok' : 'erro'}>{resultado.texto}</Alerta>}
      </form>

      <h2>Inscritos</h2>
      {inscritos.erro && <Alerta tipo="erro">{inscritos.erro}</Alerta>}
      <div className="tabela-wrap">
        <table>
          <thead><tr><th>Nome</th><th>E-mail</th><th>Situação</th><th>Presença</th></tr></thead>
          <tbody>
            {inscritos.dados?.map((i) => (
              <tr key={i.inscricaoId}>
                <td>{i.nome}</td><td>{i.email}</td><td><Badge valor={i.status} /></td>
                <td>{i.presente ? '✔' : '—'}</td>
              </tr>
            ))}
            {inscritos.dados?.length === 0 && <tr><td colSpan={4} className="muted">Nenhum inscrito.</td></tr>}
          </tbody>
        </table>
      </div>

      {e && (e.estado === 'ABERTO' || e.estado === 'LOTADO') && (
        <div className="formulario">
          <h2>Ajustes administrativos</h2>
          <form onSubmit={ajustarVagas} className="acoes">
            <label>Nova quantidade de vagas
              <input type="number" min={0} value={novasVagas} onChange={(ev) => setNovasVagas(ev.target.value === '' ? '' : Number(ev.target.value))} />
            </label>
            <button className="botao" type="submit">Ajustar vagas</button>
          </form>
          <button className="botao perigo" onClick={encerrar}>Encerrar evento</button>
        </div>
      )}
    </>
  )
}
