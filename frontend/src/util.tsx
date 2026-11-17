import { useCallback, useEffect, useState } from 'react'
import type { EstadoEvento, StatusInscricao } from './types'
import { mensagemDeErro } from './api'

export const fmtData = (iso: string) =>
  new Date(iso).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })

/** Converte o valor de <input type="datetime-local"> em ISO com fuso (UTC). */
export const paraIso = (local: string) => new Date(local).toISOString()

/** Converte ISO em valor de <input type="datetime-local"> no fuso do navegador. */
export const deIso = (iso: string) => {
  const d = new Date(iso)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

const ROTULOS: Record<string, string> = {
  ABERTO: 'Aberto',
  LOTADO: 'Lotado',
  ENCERRADO: 'Encerrado',
  REALIZADO: 'Realizado',
  CONFIRMADA: 'Confirmada',
  EM_ESPERA: 'Em espera',
  CANCELADA: 'Cancelada',
}

export function Badge({ valor }: { valor: EstadoEvento | StatusInscricao }) {
  return <span className={`badge badge-${valor.toLowerCase()}`}>{ROTULOS[valor] ?? valor}</span>
}

/** Carrega dados de uma funcao assincrona, expondo carregando/erro/recarregar. */
export function useCarregar<T>(fn: () => Promise<T>, deps: unknown[]) {
  const [dados, setDados] = useState<T | null>(null)
  const [erro, setErro] = useState<string | null>(null)
  const [carregando, setCarregando] = useState(true)

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const recarregar = useCallback(() => {
    setCarregando(true)
    fn()
      .then((d) => {
        setDados(d)
        setErro(null)
      })
      .catch((e) => setErro(mensagemDeErro(e)))
      .finally(() => setCarregando(false))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)

  useEffect(() => {
    recarregar()
  }, [recarregar])

  return { dados, erro, carregando, recarregar }
}

export function Alerta({ tipo, children }: { tipo: 'erro' | 'ok'; children: React.ReactNode }) {
  return <div className={`alerta alerta-${tipo}`}>{children}</div>
}
