import { Link } from 'react-router-dom'
import { api } from '../api'
import type { Painel } from '../types'
import { Alerta, Badge, useCarregar } from '../util'

/** RF11 – acompanhamento administrativo básico. */
export default function AdminPainel() {
  const { dados, erro, carregando } = useCarregar(() => api.get<Painel[]>('/api/painel'), [])

  return (
    <>
      <div className="linha">
        <h1>Painel administrativo</h1>
        <Link className="botao" to="/admin/eventos/novo">Novo evento</Link>
      </div>
      {erro && <Alerta tipo="erro">{erro}</Alerta>}
      {carregando && <p>Carregando…</p>}
      {dados && dados.length === 0 && <p>Nenhum evento cadastrado.</p>}
      {dados && dados.length > 0 && (
        <div className="tabela-wrap">
          <table>
            <thead>
              <tr>
                <th>Evento</th><th>Estado</th><th>Vagas</th><th>Inscritos</th>
                <th>Em espera</th><th>Presenças</th><th>Certificados</th><th></th>
              </tr>
            </thead>
            <tbody>
              {dados.map((p) => (
                <tr key={p.eventoId}>
                  <td><Link to={`/eventos/${p.eventoId}`}>{p.titulo}</Link></td>
                  <td><Badge valor={p.estado} /></td>
                  <td>{p.vagas}</td>
                  <td>{p.confirmados}</td>
                  <td>{p.emEspera}</td>
                  <td>{p.presencas}</td>
                  <td>{p.certificados}</td>
                  <td><Link to={`/admin/eventos/${p.eventoId}/checkin`}>Check-in</Link></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  )
}
