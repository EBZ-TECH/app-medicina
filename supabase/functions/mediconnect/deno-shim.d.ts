/**
 * Tipos mínimos para el IDE (Cursor/VS Code). El runtime de Supabase inyecta `Deno`.
 */
declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
  serve: (
    handler: (request: Request) => Response | Promise<Response>,
  ) => void;
};
