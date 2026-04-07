export namespace validator {
  export const isEmpty = (value: any) => (
    value === undefined ||
    value === null ||
    (typeof value === 'object' && Object.keys(value).length === 0) ||
    (typeof value === 'string' && value.trim().length === 0)
  );

  export const isJSON = (str: string): boolean => {
    try {
      const json = JSON.parse(str);
      return (typeof json === 'object' && !!str);
    } catch (e) {
      return false;
    }
  };
}
