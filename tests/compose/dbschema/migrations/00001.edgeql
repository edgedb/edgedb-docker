CREATE MIGRATION m1emptcpabfdmi7r4qiux7lraybnc6vet4vklsjer2wjvaufpbfgpq
    ONTO initial
{
  CREATE TYPE default::Counter {
      CREATE REQUIRED SINGLE PROPERTY name -> std::str {
          CREATE CONSTRAINT std::exclusive;
      };
      CREATE REQUIRED SINGLE PROPERTY visits -> std::int64 {
          SET default := 0;
      };
  };
};
