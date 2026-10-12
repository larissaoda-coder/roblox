import { useMemo, useState, type ReactNode } from 'react'
import { KeyRound, ShieldCheck, UserPlus, Users } from 'lucide-react'
import {
  Badge,
  Button,
  Card,
  CardHeader,
  DataTable,
  EmptyState,
  Field,
  FormError,
  Input,
  Modal,
  PasswordInput,
  Segmented,
  Select,
  Skeleton,
  Switch,
  useConfirm,
  useToast,
  type Column,
} from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { ROLES, ROLE_LABELS } from '@/lib/constants'
import { toMessage } from '@/lib/errors'
import { formatDateTime, formatRelative } from '@/lib/format'
import { emailSchema, passwordSchema } from '@/lib/validation'
import type { AppRole, ManagedUser, Permission } from '@/types/domain'
import { ErrorState } from '@/features/shared/ErrorState'
import { PasswordRules } from '@/features/auth/ResetPasswordPage'
import { useCreateUser, usePermissionMatrix, useSendReset, useSetUserActive, useTogglePermission, useUpdateUserRole, useUsers } from './api'

export function UsersPage() {
  const { profile } = useAuth()
  const { data, isLoading, error, refetch } = useUsers()
  const setActive = useSetUserActive()
  const updateRole = useUpdateUserRole()
  const sendReset = useSendReset()
  const toast = useToast()
  const confirm = useConfirm()
  const [adding, setAdding] = useState(false)

  const columns: Column<ManagedUser>[] = [
    {
      key: 'name',
      header: 'Usuário',
      cell: (u) => (
        <div>
          <p className="font-medium text-neutral-950">
            {u.full_name || '—'} {u.id === profile?.id && <span className="text-xs font-normal text-neutral-500">(você)</span>}
          </p>
          <p className="text-xs text-neutral-500">{u.email}</p>
        </div>
      ),
    },
    {
      key: 'role',
      header: 'Papel',
      cell: (u) =>
        u.id === profile?.id ? (
          <Badge tone="solid">{ROLE_LABELS[u.role]}</Badge>
        ) : (
          <Select
            aria-label={`Papel de ${u.full_name}`}
            className="h-8 w-40 text-xs"
            value={u.role}
            onChange={async (e) => {
              const role = e.target.value as AppRole
              try {
                await updateRole.mutateAsync({ id: u.id, role })
                toast.success(`${u.full_name} agora é ${ROLE_LABELS[role].toLowerCase()}.`)
              } catch (err) {
                toast.error(toMessage(err))
              }
            }}
          >
            {ROLES.map((r) => (
              <option key={r} value={r}>
                {ROLE_LABELS[r]}
              </option>
            ))}
          </Select>
        ),
    },
    {
      key: 'status',
      header: 'Situação',
      cell: (u) =>
        !u.active ? (
          <Badge tone="dashed">Desativado</Badge>
        ) : !u.email_confirmed_at ? (
          <Badge tone="outline">Convite pendente</Badge>
        ) : (
          <Badge tone="muted">Ativo</Badge>
        ),
    },
    {
      key: 'last',
      header: 'Último acesso',
      cell: (u) => <span className="text-neutral-600" title={formatDateTime(u.last_sign_in_at)}>{u.last_sign_in_at ? formatRelative(u.last_sign_in_at) : 'Nunca'}</span>,
    },
    {
      key: 'actions',
      header: <span className="sr-only">Ações</span>,
      align: 'right',
      cell: (u) =>
        u.id === profile?.id ? null : (
          <div className="flex items-center justify-end gap-3">
            <Button
              size="sm"
              variant="ghost"
              icon={<KeyRound className="h-3.5 w-3.5" />}
              onClick={async () => {
                if (!(await confirm({ title: 'Enviar redefinição de senha?', description: `Um link será enviado para ${u.email}.`, confirmLabel: 'Enviar' }))) return
                sendReset.mutateAsync(u.email).then(() => toast.success('E-mail de redefinição enviado.'), (e) => toast.error(toMessage(e)))
              }}
            >
              Redefinir senha
            </Button>
            <label className="flex items-center gap-2 text-xs text-neutral-600">
              <Switch
                checked={u.active}
                label={u.active ? `Desativar ${u.full_name}` : `Reativar ${u.full_name}`}
                disabled={setActive.isPending}
                onChange={async (next) => {
                  if (!next && !(await confirm({ title: 'Desativar usuário?', description: `${u.full_name} perderá o acesso imediatamente. O histórico é mantido.`, confirmLabel: 'Desativar' }))) return
                  setActive.mutateAsync({ id: u.id, active: next }).then((r) => toast.success(r.message), (e) => toast.error(toMessage(e)))
                }}
              />
              {u.active ? 'Ativo' : 'Inativo'}
            </label>
          </div>
        ),
    },
  ]

  return (
    <>
      <PageHeader
        title="Usuários e permissões"
        description="Convide a equipe, defina papéis e ajuste o que cada papel pode fazer."
        actions={
          <Button icon={<UserPlus className="h-4 w-4" />} onClick={() => setAdding(true)}>
            Adicionar usuário
          </Button>
        }
      />
      <Card className="mb-8">
        <CardHeader title="Equipe" description={data ? `${data.filter((u) => u.active).length} usuários ativos` : undefined} />
        {error ? (
          <ErrorState error={error} onRetry={() => void refetch()} />
        ) : (
          <DataTable
            caption="Usuários"
            columns={columns}
            rows={data}
            loading={isLoading}
            rowKey={(u) => u.id}
            mobileCard={(u) => (
              <div className="space-y-2.5">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="truncate font-medium text-neutral-950">
                      {u.full_name || '—'} {u.id === profile?.id && <span className="text-xs font-normal text-neutral-500">(você)</span>}
                    </p>
                    <p className="truncate text-xs text-neutral-500">{u.email}</p>
                  </div>
                  {columns[2].cell(u)}
                </div>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  {columns[1].cell(u)}
                  {columns[4].cell(u)}
                </div>
              </div>
            )}
            empty={<EmptyState icon={Users} title="Nenhum usuário" />}
          />
        )}
      </Card>
      <PermissionsMatrix />
      <AddUserModal open={adding} onClose={() => setAdding(false)} />
    </>
  )
}

function PermissionsMatrix() {
  const { data, isLoading, error, refetch } = usePermissionMatrix()
  const toggle = useTogglePermission()
  const toast = useToast()
  const editableRoles = ROLES.filter((r) => r !== 'admin')
  const set = useMemo(() => new Set((data?.matrix ?? []).map((m) => `${m.role}:${m.permission}`)), [data])

  const groups = useMemo(() => {
    const map = new Map<string, NonNullable<typeof data>['permissions']>()
    for (const p of data?.permissions ?? []) map.set(p.group_label, [...(map.get(p.group_label) ?? []), p])
    return Array.from(map.entries())
  }, [data])

  return (
    <Card>
      <CardHeader
        title="Permissões por papel"
        description="Alterações valem imediatamente. Administradores têm acesso total e não podem ser restringidos."
      />
      {error ? (
        <ErrorState error={error} onRetry={() => void refetch()} />
      ) : isLoading ? (
        <div className="space-y-2 p-5">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-10" />
          ))}
        </div>
      ) : (
        <div className="scrollbar-thin relative overflow-x-auto">
          <table className="w-full min-w-[720px] text-sm">
            <thead>
              <tr className="border-b border-neutral-200 bg-neutral-50/80">
                <th className="px-5 py-3 text-left text-[11.5px] font-semibold uppercase tracking-wide text-neutral-500">Permissão</th>
                {ROLES.map((r) => (
                  <th key={r} className="w-32 px-3 py-3 text-center text-[11.5px] font-semibold uppercase tracking-wide text-neutral-500">
                    {ROLE_LABELS[r]}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {groups.map(([group, perms]) => (
                <GroupRows key={group} group={group}>
                  {perms.map((p) => (
                    <tr key={p.code} className="border-b border-neutral-100">
                      <td className="px-5 py-3">
                        <p className="font-medium text-neutral-900">{p.label}</p>
                        <p className="text-xs text-neutral-500">{p.description}</p>
                      </td>
                      <td className="px-3 py-3 text-center">
                        <input type="checkbox" checked disabled aria-label={`${p.label} — Administrador`} className="h-4 w-4 accent-neutral-950" />
                      </td>
                      {editableRoles.map((r) => {
                        const key = `${r}:${p.code}`
                        const checked = set.has(key)
                        return (
                          <td key={r} className="px-3 py-3 text-center">
                            <input
                              type="checkbox"
                              checked={checked}
                              disabled={toggle.isPending}
                              aria-label={`${p.label} — ${ROLE_LABELS[r]}`}
                              className="h-4 w-4 cursor-pointer accent-neutral-950"
                              onChange={(e) =>
                                toggle
                                  .mutateAsync({ role: r, permission: p.code as Permission, enabled: e.target.checked })
                                  .then(() => toast.success('Permissão atualizada.'), (err) => toast.error(toMessage(err)))
                              }
                            />
                          </td>
                        )
                      })}
                    </tr>
                  ))}
                </GroupRows>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  )
}

function GroupRows({ group, children }: { group: string; children: ReactNode }) {
  return (
    <>
      <tr>
        <td colSpan={5} className="bg-white px-5 pb-1 pt-4">
          <span className="eyebrow inline-flex items-center gap-1.5">
            <ShieldCheck className="h-3.5 w-3.5" /> {group}
          </span>
        </td>
      </tr>
      {children}
    </>
  )
}

function AddUserModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const create = useCreateUser()
  const toast = useToast()
  const [mode, setMode] = useState<'invite' | 'create'>('invite')
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [role, setRole] = useState<AppRole>('vendedor')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)

  const close = () => {
    setName('')
    setEmail('')
    setPassword('')
    setRole('vendedor')
    setError(null)
    onClose()
  }

  const submit = async () => {
    setError(null)
    if (name.trim().length < 2) return setError('Informe o nome completo.')
    const e = emailSchema.safeParse(email)
    if (!e.success) return setError(e.error.issues[0].message)
    if (mode === 'create') {
      const p = passwordSchema.safeParse(password)
      if (!p.success) return setError(p.error.issues[0].message)
    }
    try {
      const res = await create.mutateAsync({ mode, email: email.trim(), full_name: name.trim(), role, password: mode === 'create' ? password : undefined })
      toast.success(res.message)
      close()
    } catch (err) {
      setError(toMessage(err))
    }
  }

  return (
    <Modal
      open={open}
      onClose={close}
      title="Adicionar usuário"
      description="A conta é criada no servidor; senhas nunca são armazenadas em texto puro."
      footer={
        <>
          <Button variant="secondary" onClick={close}>
            Cancelar
          </Button>
          <Button onClick={submit} loading={create.isPending}>
            {mode === 'invite' ? 'Enviar convite' : 'Criar usuário'}
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <Segmented
          ariaLabel="Forma de cadastro"
          value={mode}
          onChange={setMode}
          items={[
            { value: 'invite', label: 'Convite por e-mail' },
            { value: 'create', label: 'Definir senha inicial' },
          ]}
        />
        <FormError message={error} />
        <Field label="Nome completo" required>
          <Input value={name} onChange={(e) => setName(e.target.value)} />
        </Field>
        <Field label="E-mail" required>
          <Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="off" />
        </Field>
        <Field label="Papel de acesso" required>
          <Select value={role} onChange={(e) => setRole(e.target.value as AppRole)}>
            {ROLES.map((r) => (
              <option key={r} value={r}>
                {ROLE_LABELS[r]}
              </option>
            ))}
          </Select>
        </Field>
        {mode === 'create' ? (
          <>
            <Field label="Senha inicial" required hint="Compartilhe com o usuário por um canal seguro e peça que ele a altere no primeiro acesso.">
              <PasswordInput value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="new-password" />
            </Field>
            <PasswordRules value={password} />
          </>
        ) : (
          <p className="text-xs text-neutral-500">O usuário receberá um e-mail com o link para definir a própria senha.</p>
        )}
      </div>
    </Modal>
  )
}
