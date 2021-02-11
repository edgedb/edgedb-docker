CREATE MIGRATION m1gcgrb7grg2zfq764refma5fevmfumvok5hy2qwnljb7i3qhnjz2a
    ONTO initial
{
  CREATE TYPE default::Item {
      CREATE REQUIRED PROPERTY name -> std::str;
  };
};
