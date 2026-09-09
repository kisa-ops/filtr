import React, { useState, useRef, useCallback, useEffect } from 'react';

interface SplitPaneProps {
  left: React.ReactNode;
  right: React.ReactNode;
  initialSplit?: number; // percentage (default 50)
  minLeft?: number; // min percentage (default 25)
  minRight?: number; // min percentage (default 25)
}

export const SplitPane: React.FC<SplitPaneProps> = ({
  left,
  right,
  initialSplit = 50,
  minLeft = 25,
  minRight = 25
}) => {
  const [splitPercent, setSplitPercent] = useState(initialSplit);
  const [isDragging, setIsDragging] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  const handleMouseDown = (e: React.MouseEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleTouchStart = () => {
    setIsDragging(true);
  };

  const onMove = useCallback(
    (clientX: number) => {
      if (!isDragging || !containerRef.current) return;
      const rect = containerRef.current.getBoundingClientRect();
      const newPercent = ((clientX - rect.left) / rect.width) * 100;
      if (newPercent >= minLeft && newPercent <= 100 - minRight) {
        setSplitPercent(newPercent);
      }
    },
    [isDragging, minLeft, minRight]
  );

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      onMove(e.clientX);
    };
    const handleTouchMove = (e: TouchEvent) => {
      if (e.touches[0]) onMove(e.touches[0].clientX);
    };
    const handleEnd = () => {
      setIsDragging(false);
    };

    if (isDragging) {
      window.addEventListener('mousemove', handleMouseMove);
      window.addEventListener('mouseup', handleEnd);
      window.addEventListener('touchmove', handleTouchMove);
      window.addEventListener('touchend', handleEnd);
    }
    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleEnd);
      window.removeEventListener('touchmove', handleTouchMove);
      window.removeEventListener('touchend', handleEnd);
    };
  }, [isDragging, onMove]);

  return (
    <div 
      ref={containerRef} 
      className="flex flex-1 w-full h-full overflow-hidden relative select-none"
    >
      {/* Left Pane */}
      <div 
        style={{ width: `${splitPercent}%` }}
        className="h-full overflow-hidden flex flex-col"
      >
        {left}
      </div>

      {/* Divider Bar */}
      <div
        onMouseDown={handleMouseDown}
        onTouchStart={handleTouchStart}
        className={`w-2 relative z-20 cursor-col-resize flex items-center justify-center transition-colors ${
          isDragging 
            ? 'bg-indigo-500 shadow-lg shadow-indigo-500/50' 
            : 'bg-slate-800/80 hover:bg-indigo-500/60'
        }`}
      >
        <div className="h-8 w-1 rounded-full bg-slate-500/60 pointer-events-none" />
      </div>

      {/* Right Pane */}
      <div 
        style={{ width: `${100 - splitPercent}%` }}
        className="h-full overflow-hidden flex flex-col"
      >
        {right}
      </div>
    </div>
  );
};
