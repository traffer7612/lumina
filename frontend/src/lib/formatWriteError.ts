import { BaseError, decodeErrorResult, type Abi } from 'viem';

/**
 * Best-effort message for failed wallet writes: viem shortMessage + optional ABI decode.
 */
export function formatWriteContractError(err: unknown, abi?: Abi): string {
  if (err instanceof BaseError) {
    let data: `0x${string}` | undefined;
    err.walk((e) => {
      const d = (e as { data?: unknown }).data;
      if (typeof d === 'string' && d.startsWith('0x') && d.length >= 10) {
        data = d as `0x${string}`;
        return false;
      }
      return true;
    });
    if (data && abi?.length) {
      try {
        const { errorName, args } = decodeErrorResult({ abi, data });
        const argStr = args && args.length ? ` ${JSON.stringify(args)}` : '';
        return `${errorName}${argStr}`;
      } catch {
        /* fall through */
      }
    }
    const detail = err.details ? ` — ${err.details}` : '';
    return `${err.shortMessage}${detail}`.slice(0, 400);
  }
  if (err instanceof Error) return err.message.split('\n')[0].slice(0, 400);
  return String(err).slice(0, 400);
}

/** Short user hint for known Ceitnot engine custom errors (RU). */
export function hintForEngineError(decodedLine: string): string | undefined {
  if (decodedLine.includes('Ceitnot__SameBlockInteraction'))
    return 'В одном блоке по этому рынку уже была операция. Подождите следующий блок или отправьте одну транзакцию.';
  if (decodedLine.includes('Ceitnot__IsolationViolation'))
    return 'Режим изоляции: нельзя иметь залог/долг на другом рынке одновременно с этим.';
  if (decodedLine.includes('Ceitnot__InvalidParams'))
    return 'Часто не хватает approve на Engine для vault shares, или vault не принял transferFrom.';
  if (decodedLine.includes('Ceitnot__MarketFrozen')) return 'Рынок заморожен (frozen).';
  if (decodedLine.includes('Ceitnot__MarketInactive')) return 'Рынок выключен (inactive).';
  if (decodedLine.includes('Ceitnot__Paused')) return 'Движок на паузе.';
  if (decodedLine.includes('Ceitnot__EmergencyShutdown')) return 'Включён emergency shutdown.';
  if (decodedLine.includes('Ceitnot__SupplyCapExceeded')) return 'Достигнут supply cap рынка.';
  if (decodedLine.includes('Ceitnot__ZeroAmount')) return 'Сумма 0 — введите положительное количество shares.';
  return undefined;
}
