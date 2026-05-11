import React from 'react';
import { Composition } from 'remotion';
import { Hook } from './compositions/Hook';

const FPS = 60;

export const Root: React.FC = () => {
  return (
    <>
      <Composition
        id="Hook"
        component={Hook}
        durationInFrames={FPS * 5}
        fps={FPS}
        width={1920}
        height={1080}
      />
    </>
  );
};
