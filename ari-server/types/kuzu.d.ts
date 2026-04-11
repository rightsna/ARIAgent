declare module "kuzu" {
  class Database {
    constructor(path: string, bufferPoolSize?: number);
    close(): void;
  }

  class Connection {
    constructor(db: Database, numThreads?: number);
    query(statement: string): Promise<QueryResult>;
    prepare(statement: string): Promise<PreparedStatement>;
    execute(prepared: PreparedStatement, params?: Record<string, any>): Promise<QueryResult>;
    close(): void;
  }

  interface QueryResult {
    getAll(): Promise<Record<string, any>[]>;
    getNext(): Promise<Record<string, any> | null>;
    close(): void;
  }

  interface PreparedStatement {}

  const _default: {
    Database: typeof Database;
    Connection: typeof Connection;
  };

  export = _default;
}
