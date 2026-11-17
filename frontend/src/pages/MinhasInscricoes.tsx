import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { QRCodeSVG } from 'qrcode.react'
import { api, mensagemDeErro } from '../api'
import type { MinhaInscricao } from '../types'
import { Alerta, Badge, fmtData, useCarregar } from '../util'

/** RF08 – área do participante: inscrições, posição na fila, QR de check-in e certificados. */
export default function MinhasInscricoes() {
  const { dados, erro, carregando, recarregar } = useCarregar(() => api.get<MinhaInscricao[]>('/api/inscricoes/minhas'), [])
  const [msg, setMsg] = useState<string | null>(null)
  const navigate = useNavigate()

  async function cancelar(i: MinhaInscricao) {
    if (!window.confirm(`Cancelar a inscrição em "${i.eventoTitulo}"?`)) return
    setMsg(null)
    try {
      await api.del(`/api/inscricoes/${i.id}`)
      recarregar()
    } catch (e) {
      setMsg(mensagemDeErro(e))
    }
  }

  async function emitir(i: MinhaInscricao) {
    setMsg(null)
    try {
      await api.post(`/api/inscricoes/${i.id}/certificado`)
      navigate(`/certificado/${i.id}`)
    } catch (e) {
      setMsg(mensagemDeErro(e))
    }
  }

  const ativa = (i: MinhaInscricao) => i.status !== 'CANCELADA' && (i.estadoEvento === 'ABERTO' || i.estadoEvento === 'LOTADO')

  return (
    <>
      <h1>Minhas inscrições</h1>
      {erro && <Alerta tipo="erro">{erro}</Alerta>}
      {msg && <Alerta tipo="erro">{msg}</Alerta>}
      {carregando && <p>Carregando…</p>}
      {dados && dados.length === 0 && (
        <p>Você ainda não tem inscrições. <Link to="/">Ver eventos</Link></p>
      )}
      <div className="grade">
        {dados?.map((i) => (
          <article key={i.id} className="cartao">
            <div className="linha">
              <h3>{i.eventoTitulo}</h3>
              <Badge valor={i.status} />
            </div>
            <p className="muted">{fmtData(i.inicio)} · {i.localNome}</p>
            {i.status === 'EM_ESPERA' && <p>Posição na fila: <strong>{i.posicaoFila}º</strong></p>}
            {i.status === 'CONFIRMADA' && i.codigoCheckin && !i.presente && (
              <div className="qr">
                <QRCodeSVG value={i.codigoCheckin} size={120} />
                <code>{i.codigoCheckin}</code>
                <small className="muted">Apresente este QR Code no check-in.</small>
              </div>
            )}
            {i.presente && <p>✔ Presença registrada</p>}
            <div className="acoes">
              {ativa(i) && !i.presente && (
                <button className="botao perigo" onClick={() => cancelar(i)}>Cancelar inscrição</button>
              )}
              {i.presente && i.codigoCertificado && (
                <Link className="botao" to={`/certificado/${i.id}`}>Ver certificado</Link>
              )}
              {i.presente && !i.codigoCertificado && (i.estadoEvento === 'REALIZADO' || new Date(i.fim) <= new Date()) && (
                <button className="botao" onClick={() => emitir(i)}>Emitir certificado</button>
              )}
            </div>
          </article>
        ))}
      </div>
    </>
  )
}
