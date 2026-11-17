import { Link, useParams } from 'react-router-dom'
import { api } from '../api'
import type { CertificadoDados } from '../types'
import { Alerta, fmtData, useCarregar } from '../util'

/** RF10 – certificado para visualizar/imprimir, com código de verificação. */
export default function CertificadoView() {
  const { inscricaoId } = useParams()
  const { dados, erro, carregando } = useCarregar(
    () => api.get<CertificadoDados>(`/api/inscricoes/${inscricaoId}/certificado`),
    [inscricaoId],
  )

  if (carregando) return <p>Carregando…</p>
  if (erro) return <Alerta tipo="erro">{erro}</Alerta>
  if (!dados) return null

  return (
    <>
      <p className="nao-imprimir"><Link to="/minhas">← Minhas inscrições</Link></p>
      <section className="certificado">
        <h1>Certificado de Participação</h1>
        <p>Certificamos que</p>
        <p className="destaque">{dados.participante}</p>
        <p>
          participou do evento <strong>{dados.evento}</strong>, realizado em {fmtData(dados.dataEvento)},
          com carga horária de <strong>{dados.cargaHoraria} hora(s)</strong>.
        </p>
        <p className="muted">Emitido em {fmtData(dados.emitidoEm)}</p>
        <p className="codigo">Código de verificação:<br /><code>{dados.codigo}</code></p>
      </section>
      <p className="nao-imprimir">
        <button className="botao" onClick={() => window.print()}>Imprimir / salvar em PDF</button>
      </p>
    </>
  )
}
