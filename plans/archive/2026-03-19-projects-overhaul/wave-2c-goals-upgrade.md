# Wave 2C — Goals: Styled Button + Hover Edit

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Upgrade the ProjectGoals component:
1. Replace the plain text "+ Add Goal" with a styled button matching the section standard
2. Add a hover-only edit button per goal
3. Add inline goal editing

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md`
2. `/Users/gregor/dev/922/HomeUI/src/features/projects/sections/ProjectGoals.tsx` — component to modify
3. `/Users/gregor/dev/922/HomeUI/src/features/projects/sections/ProjectHeader.tsx` — reference for "Edit Project" button style (lines 112-118)
4. `/Users/gregor/dev/922/HomeUI/src/features/projects/sections/ProjectGoals.test.tsx` — tests to satisfy (from Wave 1C)

## Changes

### 1. Add Goal Button Style
Replace the plain text button (lines 131-137) with the standard zinc style:

```tsx
// Current (plain text):
<button className="font-mono text-[10px] text-zinc-500 hover:text-zinc-300 bg-transparent border-none cursor-pointer" style={{ padding: 0 }}>
  + Add Goal
</button>

// New (zinc pill, matches "Edit Project" style):
<button className="font-mono text-[11px] text-zinc-400 hover:text-zinc-200 bg-zinc-800 hover:bg-zinc-700 transition-colors cursor-pointer border-none" style={{ padding: '0.375rem 0.75rem', borderRadius: 6 }}>
  + Add Goal
</button>
```

### 2. Hover Edit Button
Add a small edit button to each goal row that appears only on hover. Use Tailwind `group` pattern:

```tsx
<div key={index} className="group/goal" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
  {/* existing checkbox + title */}
  <button
    type="button"
    onClick={() => startEdit(index)}
    className="opacity-0 group-hover/goal:opacity-100 font-mono text-[9px] text-zinc-500 hover:text-zinc-300 bg-transparent border-none cursor-pointer transition-opacity"
    aria-label={`Edit goal: ${goal.title}`}
    style={{ padding: '2px 4px', flexShrink: 0 }}
  >
    Edit
  </button>
</div>
```

### 3. Inline Edit State
Add state for editing:
```tsx
const [editingIndex, setEditingIndex] = useState<number | null>(null)
const [editTitle, setEditTitle] = useState('')
```

When editing, replace the goal text with an input:
```tsx
{editingIndex === index ? (
  <div style={{ display: 'flex', gap: '0.375rem', flex: 1 }}>
    <input
      type="text"
      value={editTitle}
      onChange={(e) => setEditTitle(e.target.value)}
      onKeyDown={(e) => {
        if (e.key === 'Enter') { saveEdit(index) }
        if (e.key === 'Escape') { setEditingIndex(null) }
      }}
      autoFocus
      className="font-mono text-xs bg-zinc-900 text-zinc-300 border border-zinc-700 focus:outline-none focus:border-zinc-500"
      style={{ padding: '0.25rem 0.5rem', flex: 1, borderRadius: 6 }}
    />
  </div>
) : (
  <span ...>{goal.title}</span>
)}
```

Add `startEdit` and `saveEdit` functions:
```tsx
function startEdit(index: number) {
  setEditingIndex(index)
  setEditTitle(goals[index].title)
}

function saveEdit(index: number) {
  if (!editTitle.trim()) return
  const updated = [...goals]
  updated[index] = { ...updated[index], title: editTitle.trim() }
  patchContext.mutate(
    { slug, updates: { goals: updated } },
    { onSettled: () => { void queryClient.invalidateQueries({ queryKey: ['projects'] }); setEditingIndex(null) } },
  )
}
```

### 4. Also add a delete button (hover-only, next to edit)
Small "x" or "Delete" text that removes the goal from the array.

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

## Verification
1. Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/features/projects/sections/ProjectGoals` — all tests including hover edit should pass
2. Run `cd /Users/gregor/dev/922/HomeUI && npm run build`
