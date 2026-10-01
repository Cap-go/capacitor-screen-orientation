import { describe, expect, it } from 'vitest';

import { sizeClassOf } from './size-class';

describe('sizeClassOf', () => {
  it('classifies a phone width as compact', () => {
    expect(sizeClassOf(390, 844)).toMatchObject({
      horizontal: 'compact',
      widthClass: 'compact',
      heightClass: 'medium',
    });
  });

  it('classifies a wide inner display as expanded', () => {
    expect(sizeClassOf(900, 1000)).toMatchObject({
      horizontal: 'regular',
      widthClass: 'expanded',
    });
  });
});
