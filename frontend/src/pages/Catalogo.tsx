import { Link } from 'react-router-dom'
import { api } from '../api'
import type { Evento } from '../types'
import { Alerta, Badge, fmtData, useCarregar } from '../util'

/** RF05 – catálogo de eventos. */
export default function Catalogo() {
  const { dados, erro, carregando } = useCarregar(() => api.get<Evento[]>('/api/eventos'), [])

  return (
    <>
      <h1>Eventos</h1>
      {erro && <Alerta tipo="erro">{erro}</Alerta>}
      {carregando && <p>Carregando…</p>}
      {dados && dados.length === 0 && <p>Nenhum evento disponível no momento.</p>}
      <div className="grade">
        {dados?.map((e) => {
          const livres = Math.max(e.vagas - e.confirmados, 0)
          return (
            <article key={e.id} className="cartao">
              <div className="linha">
                <h3>{e.titulo}</h3>
                <Badge valor={e.estado} />
              </div>
              <p className="muted">{fmtData(e.inicio)} – {fmtData(e.fim)}</p>
              <p>{e.localNome} · {e.localizacao}</p>
              <p>
                <strong>{livres}</strong> de {e.vagas} vagas livres
                {e.emEspera > 0 && <> · {e.emEspera} na fila</>}
              </p>
              <Link className="botao" to={`/eventos/${e.id}`}>Ver detalhes</Link>
            </article>
          )
        })}
      </div>
    </>
  )
}
