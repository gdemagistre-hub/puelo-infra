class Herramienta {
  const Herramienta({
    required this.id,
    required this.nombre,
    required this.oficio,
    required this.precio,
    required this.descripcion,
  });

  final String id;
  final String nombre;
  final String oficio;
  final double precio;
  final String descripcion;
}

const catalogoHerramientas = <Herramienta>[
  Herramienta(
    id: 'taladro',
    nombre: 'Taladro percutor',
    oficio: 'Electricidad / General',
    precio: 185000,
    descripcion: 'Ideal para instalaciones y montajes del día a día.',
  ),
  Herramienta(
    id: 'amoladora',
    nombre: 'Amoladora angular',
    oficio: 'Herrería / General',
    precio: 160000,
    descripcion: 'Corte y desbaste en obra.',
  ),
  Herramienta(
    id: 'rotomartillo',
    nombre: 'Rotomartillo',
    oficio: 'Albañilería',
    precio: 320000,
    descripcion: 'Para hormigón y trabajos pesados.',
  ),
  Herramienta(
    id: 'cortadora',
    nombre: 'Cortadora de césped',
    oficio: 'Jardinería',
    precio: 210000,
    descripcion: 'Para mantenimiento de espacios verdes.',
  ),
  Herramienta(
    id: 'kit_plomeria',
    nombre: 'Kit básico plomería',
    oficio: 'Plomería',
    precio: 95000,
    descripcion: 'Llaves, cinta, destapador y básicos de cañería.',
  ),
  Herramienta(
    id: 'compresor',
    nombre: 'Compresor portátil',
    oficio: 'Pintura / General',
    precio: 280000,
    descripcion: 'Para pintura y herramientas neumáticas.',
  ),
];
