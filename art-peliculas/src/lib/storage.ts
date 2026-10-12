import { useQuery } from '@tanstack/react-query'
import { MEDIA_BUCKET, supabase } from './supabase'

const SIGNED_URL_TTL = 60 * 60 // 1 hora

export async function uploadMedia(path: string, file: Blob, contentType: string) {
  const { error } = await supabase.storage.from(MEDIA_BUCKET).upload(path, file, {
    contentType,
    upsert: false,
    cacheControl: '3600',
  })
  if (error) throw error
  return path
}

export async function removeMedia(paths: Array<string | null | undefined>) {
  const valid = paths.filter((p): p is string => Boolean(p))
  if (valid.length === 0) return
  const { error } = await supabase.storage.from(MEDIA_BUCKET).remove(valid)
  if (error) throw error
}

export async function signedUrls(paths: string[]) {
  if (paths.length === 0) return {} as Record<string, string>
  const { data, error } = await supabase.storage.from(MEDIA_BUCKET).createSignedUrls(paths, SIGNED_URL_TTL)
  if (error) throw error
  const map: Record<string, string> = {}
  for (const item of data ?? []) {
    if (item.path && item.signedUrl) map[item.path] = item.signedUrl
  }
  return map
}

/** URLs assinadas (bucket privado) com cache de 50 minutos. */
export function useSignedUrls(paths: Array<string | null | undefined>) {
  const unique = Array.from(new Set(paths.filter((p): p is string => Boolean(p)))).sort()
  return useQuery({
    queryKey: ['signed-urls', unique],
    queryFn: () => signedUrls(unique),
    enabled: unique.length > 0,
    staleTime: 50 * 60 * 1000,
    gcTime: 55 * 60 * 1000,
  })
}

export function useSignedUrl(path: string | null | undefined) {
  const query = useSignedUrls([path])
  return { ...query, url: path ? query.data?.[path] : undefined }
}

export function fileExtension(name: string) {
  const m = /\.([a-z0-9]+)$/i.exec(name)
  return m ? m[1].toLowerCase() : ''
}

export function randomName(ext: string) {
  const id = crypto.randomUUID()
  return ext ? `${id}.${ext}` : id
}

export interface PreparedImage {
  blob: Blob
  width: number
  height: number
  contentType: string
  extension: string
}

function loadImage(file: Blob) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload = () => {
      URL.revokeObjectURL(url)
      resolve(img)
    }
    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('Não foi possível ler a imagem. Use arquivos JPG, PNG ou WebP.'))
    }
    img.src = url
  })
}

/**
 * Reduz imagens muito grandes (lado maior até `maxSize` px) antes do envio,
 * preservando a proporção. Mantém o arquivo original quando já é pequeno.
 */
export async function prepareImage(file: File, maxSize = 2400): Promise<PreparedImage> {
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
    throw new Error('Formato não suportado. Envie imagens JPG, PNG ou WebP.')
  }
  const img = await loadImage(file)
  const { naturalWidth: w, naturalHeight: h } = img
  const scale = Math.min(1, maxSize / Math.max(w, h))
  const ext = (t: string) => (t === 'image/png' ? 'png' : t === 'image/webp' ? 'webp' : 'jpg')

  if (scale === 1 && file.size <= 4 * 1024 * 1024) {
    return { blob: file, width: w, height: h, contentType: file.type, extension: ext(file.type) }
  }

  const width = Math.round(w * scale)
  const height = Math.round(h * scale)
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d')
  if (!ctx) throw new Error('Não foi possível processar a imagem neste navegador.')
  ctx.imageSmoothingQuality = 'high'
  ctx.drawImage(img, 0, 0, width, height)
  const blob = await new Promise<Blob>((resolve, reject) =>
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('Falha ao processar a imagem.'))), 'image/webp', 0.9),
  )
  return { blob, width, height, contentType: blob.type, extension: ext(blob.type) }
}
