import { FormEvent, useState } from 'react'
import { api, mensagemDeErro } from '../api'
import type { CertificadoVerificado } from '../types'
import { Alerta, fmtData } from '../util'

/** UC14 – verificação de validade de certificado pelo código. */
export default function VerificarCertificado() {
  const [codigo, setCodigo] = useState('')
  const [resultado, setResultado] = useState<CertificadoVerificado | null>(null)
  const [erro, setErro] = useState<string | null>(null)

  async function verificar(ev: FormEvent) {
    ev.preventDefault()
    setResultado(null)
    setErro(null)
    try {
      setResultado(await api.get<CertificadoVerificado>(`/api/certificados/verificar/${encodeURIComponent(codigo.trim())}`))
    } catch (e) {
      setErro(mensagemDeErro(e))
    }
  }

  return (
    <>
      <h1>Verificar certificado</h1>
      <form className="formulario" onSubmit={verificar}>
        <label>Código de verificação
          <input required value={codigo} onChange={(e) => setCodigo(e.target.value)} />
        </label>
        <button className="botao" type="submit">Verificar</button>
      </form>
      {erro && <Alerta tipo="erro">{erro}</Alerta>}
      {resultado && (
        <Alerta tipo="ok">
          Certificado VÁLIDO – {resultado.participante} participou de “{resultado.evento}” em{' '}
          {fmtData(resultado.dataEvento)} ({resultado.cargaHoraria} h). Emitido em {fmtData(resultado.emitidoEm)}.
        </Alerta>
      )}
    </>
  )
}
