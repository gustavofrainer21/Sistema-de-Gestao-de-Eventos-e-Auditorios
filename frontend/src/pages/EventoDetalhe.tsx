import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api, mensagemDeErro } from '../api'
import { isAdmin } from '../keycloak'
import type { Detalhe } from '../types'
import { Alerta, Badge, fmtData, useCarregar } from '../util'

/** RF05 detalhe + RF06/RF07 inscrição e fila de espera. */
export default function EventoDetalhe() {
  const { id } = useParams()
  const { dados, erro, carregando, recarregar } = useCarregar(() => api.get<Detalhe>(`/api/eventos/${id}`), [id])
  const [msg, setMsg] = useState<{ tipo: 'erro' | 'ok'; texto: string } | null>(null)
  const [enviando, setEnviando] = useState(false)

  async function inscrever(fila: boolean) {
    setEnviando(true)
    setMsg(null)
    try {
      const r = await api.post<{ status: string }>(`/api/eventos/${id}/inscricoes?fila=${fila}`)
      setMsg({
        tipo: 'ok',
        texto: r.status === 'CONFIRMADA' ? 'Inscrição confirmada!' : 'Você entrou na fila de espera.',
      })
      recarregar()
    } catch (e) {
      setMsg({ tipo: 'erro', texto: mensagemDeErro(e) })
    } finally {
      setEnviando(false)
    }
  }

  if (carregando && !dados) return <p>Carregando…</p>
  if (erro) return <Alerta tipo="erro">{erro}</Alerta>
  if (!dados) return null

  const { evento: e, subeventos } = dados
  const livres = Math.max(e.vagas - e.confirmados, 0)

  return (
    <>
      <p><Link to="/">← Voltar ao catálogo</Link></p>
      <div className="linha">
        <h1>{e.titulo}</h1>
        <Badge valor={e.estado} />
      </div>
      <p className="muted">{fmtData(e.inicio)} – {fmtData(e.fim)} · {e.cargaHoraria} h</p>
      <p>{e.localNome} · {e.localizacao}</p>
      {e.descricao && <p>{e.descricao}</p>}
      <p>
        <strong>{livres}</strong> de {e.vagas} vagas livres · {e.emEspera} na fila de espera
      </p>

      {msg && <Alerta tipo={msg.tipo}>{msg.texto}</Alerta>}

      <div className="acoes">
        {e.estado === 'ABERTO' && (
          <button className="botao" disabled={enviando} onClick={() => inscrever(false)}>Inscrever-se</button>
        )}
        {e.estado === 'LOTADO' && (
          <button className="botao" disabled={enviando} onClick={() => inscrever(true)}>
            Entrar na fila de espera
          </button>
        )}
        {(e.estado === 'ENCERRADO' || e.estado === 'REALIZADO') && <span className="muted">Inscrições encerradas.</span>}
        {isAdmin() && (
          <>
            <Link className="botao secundario" to={`/admin/eventos/${e.id}/checkin`}>Check-in e inscritos</Link>
            <Link className="botao secundario" to={`/admin/eventos/${e.id}/editar`}>Editar</Link>
          </>
        )}
      </div>

      {subeventos.length > 0 && (
        <>
          <h2>Programação (subeventos)</h2>
          <ul className="lista">
            {subeventos.map((s) => (
              <li key={s.id}>
                <strong>{s.titulo}</strong> – {fmtData(s.inicio)} às {fmtData(s.fim)} · {s.localNome}
              </li>
            ))}
          </ul>
        </>
      )}
    </>
  )
}
