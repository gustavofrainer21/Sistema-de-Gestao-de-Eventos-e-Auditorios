import { keycloak } from './keycloak'

const API = import.meta.env.VITE_API_URL ?? 'http://localhost:8080'

export class ApiError extends Error {
  status: number
  codigo: string
  constructor(status: number, codigo: string, mensagem: string) {
    super(mensagem)
    this.status = status
    this.codigo = codigo
  }
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  try {
    await keycloak.updateToken(30)
  } catch {
    await keycloak.login()
  }
  const res = await fetch(API + path, {
    method,
    headers: {
      Authorization: `Bearer ${keycloak.token}`,
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })
  if (!res.ok) {
    let data: { codigo?: string; mensagem?: string } = {}
    try {
      data = await res.json()
    } catch {
      /* corpo vazio */
    }
    throw new ApiError(res.status, data.codigo ?? 'ERRO', data.mensagem ?? `Erro ${res.status}`)
  }
  if (res.status === 204) return undefined as T
  return (await res.json()) as T
}

export const api = {
  get: <T,>(path: string) => request<T>('GET', path),
  post: <T,>(path: string, body?: unknown) => request<T>('POST', path, body ?? {}),
  put: <T,>(path: string, body: unknown) => request<T>('PUT', path, body),
  patch: <T,>(path: string, body?: unknown) => request<T>('PATCH', path, body ?? {}),
  del: (path: string) => request<void>('DELETE', path),
}

export const mensagemDeErro = (e: unknown) => (e instanceof Error ? e.message : 'Erro inesperado.')
