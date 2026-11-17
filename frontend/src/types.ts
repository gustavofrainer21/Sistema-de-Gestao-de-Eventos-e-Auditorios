export type EstadoEvento = 'ABERTO' | 'LOTADO' | 'ENCERRADO' | 'REALIZADO'
export type StatusInscricao = 'CONFIRMADA' | 'EM_ESPERA' | 'CANCELADA'

export interface Local {
  id: string
  nome: string
  capacidade: number
  localizacao: string
  ativo: boolean
}

export interface Bloqueio {
  id: string
  localId: string
  inicio: string
  fim: string
  motivo: string | null
}

export interface Evento {
  id: string
  eventoPaiId: string | null
  titulo: string
  descricao: string | null
  localId: string
  localNome: string
  localizacao: string
  inicio: string
  fim: string
  vagas: number
  estado: EstadoEvento
  cargaHoraria: number
  confirmados: number
  emEspera: number
}

export interface Detalhe {
  evento: Evento
  subeventos: Evento[]
}

export interface Inscrito {
  inscricaoId: string
  usuarioId: string
  nome: string
  email: string
  status: StatusInscricao
  criadoEm: string
  presente: boolean
}

export interface Painel {
  eventoId: string
  titulo: string
  estado: EstadoEvento
  vagas: number
  confirmados: number
  emEspera: number
  presencas: number
  certificados: number
}

export interface MinhaInscricao {
  id: string
  eventoId: string
  eventoTitulo: string
  estadoEvento: EstadoEvento
  inicio: string
  fim: string
  localNome: string
  status: StatusInscricao
  posicaoFila: number | null
  codigoCheckin: string | null
  presente: boolean
  codigoCertificado: string | null
}

export interface CertificadoDados {
  participante: string
  evento: string
  dataEvento: string
  cargaHoraria: number
  emitidoEm: string
  codigo: string
}

export interface CheckinResultado {
  aceito: boolean
  participante: string
  registradoEm: string
}

export interface CertificadoVerificado {
  valido: boolean
  participante: string
  evento: string
  dataEvento: string
  cargaHoraria: number
  emitidoEm: string
}
