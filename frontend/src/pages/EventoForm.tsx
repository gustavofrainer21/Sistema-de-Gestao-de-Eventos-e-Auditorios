import { FormEvent, useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { api, mensagemDeErro } from '../api'
import type { Detalhe, Evento, Local } from '../types'
import { Alerta, deIso, paraIso, useCarregar } from '../util'

/** RF04 – cadastro/edição de eventos e subeventos, apoiado pela consulta de disponibilidade (RF03). */
export default function EventoForm() {
  const { id } = useParams()
  const navigate = useNavigate()
  const locais = useCarregar(() => api.get<Local[]>('/api/locais'), [])
  const principais = useCarregar(() => api.get<Evento[]>('/api/eventos'), [])

  const [titulo, setTitulo] = useState('')
  const [descricao, setDescricao] = useState('')
  const [localId, setLocalId] = useState('')
  const [inicio, setInicio] = useState('')
  const [fim, setFim] = useState('')
  const [vagas, setVagas] = useState(30)
  const [carga, setCarga] = useState(2)
  const [paiId, setPaiId] = useState('')
  const [erro, setErro] = useState<string | null>(null)
  const [dica, setDica] = useState<string | null>(null)

  useEffect(() => {
    if (!id) return
    api.get<Detalhe>(`/api/eventos/${id}`)
      .then(({ evento: e }) => {
        setTitulo(e.titulo)
        setDescricao(e.descricao ?? '')
        setLocalId(e.localId)
        setInicio(deIso(e.inicio))
        setFim(deIso(e.fim))
        setVagas(e.vagas)
        setCarga(e.cargaHoraria)
        setPaiId(e.eventoPaiId ?? '')
      })
      .catch((e) => setErro(mensagemDeErro(e)))
  }, [id])

  async function verDisponiveis() {
    setDica(null)
    if (!inicio || !fim) {
      setDica('Informe início e término para consultar a disponibilidade.')
      return
    }
    try {
      const qs = new URLSearchParams({ inicio: paraIso(inicio), fim: paraIso(fim), capacidade: String(vagas || 1) })
      const livres = await api.get<Local[]>(`/api/locais/disponiveis?${qs}`)
      setDica(
        livres.length === 0
          ? 'Nenhum local disponível neste horário com essa capacidade.'
          : `Disponíveis: ${livres.map((l) => `${l.nome} (${l.capacidade})`).join(', ')}`,
      )
    } catch (e) {
      setDica(mensagemDeErro(e))
    }
  }

  async function salvar(ev: FormEvent) {
    ev.preventDefault()
    setErro(null)
    const corpo = {
      eventoPaiId: paiId || null,
      titulo,
      descricao: descricao || null,
      localId,
      inicio: paraIso(inicio),
      fim: paraIso(fim),
      vagas,
      cargaHoraria: carga,
    }
    try {
      const salvo = id ? await api.put<Evento>(`/api/eventos/${id}`, corpo) : await api.post<Evento>('/api/eventos', corpo)
      navigate(`/eventos/${salvo.id}`)
    } catch (e) {
      setErro(mensagemDeErro(e))
    }
  }

  return (
    <>
      <h1>{id ? 'Editar evento' : 'Novo evento'}</h1>
      {erro && <Alerta tipo="erro">{erro}</Alerta>}
      <form className="formulario" onSubmit={salvar}>
        <label>Título<input required value={titulo} onChange={(e) => setTitulo(e.target.value)} /></label>
        <label>Descrição<textarea rows={3} value={descricao} onChange={(e) => setDescricao(e.target.value)} /></label>
        <label>Evento principal (opcional – para cadastrar um subevento)
          <select value={paiId} onChange={(e) => setPaiId(e.target.value)} disabled={!!id}>
            <option value="">Nenhum (evento principal)</option>
            {principais.dados?.filter((p) => p.id !== id).map((p) => <option key={p.id} value={p.id}>{p.titulo}</option>)}
          </select>
        </label>
        <div className="duas">
          <label>Início<input type="datetime-local" required value={inicio} onChange={(e) => setInicio(e.target.value)} /></label>
          <label>Término<input type="datetime-local" required value={fim} onChange={(e) => setFim(e.target.value)} /></label>
        </div>
        <div className="duas">
          <label>Vagas<input type="number" min={0} required value={vagas} onChange={(e) => setVagas(Number(e.target.value))} /></label>
          <label>Carga horária (h)<input type="number" min={0.5} step={0.5} required value={carga} onChange={(e) => setCarga(Number(e.target.value))} /></label>
        </div>
        <label>Local
          <select required value={localId} onChange={(e) => setLocalId(e.target.value)}>
            <option value="">Selecione…</option>
            {locais.dados?.filter((l) => l.ativo).map((l) => <option key={l.id} value={l.id}>{l.nome} – {l.capacidade} lugares</option>)}
          </select>
        </label>
        <button className="botao secundario" type="button" onClick={verDisponiveis}>Ver locais disponíveis neste horário</button>
        {dica && <p className="muted">{dica}</p>}
        <div className="acoes">
          <button className="botao" type="submit">Salvar evento</button>
        </div>
      </form>
    </>
  )
}
