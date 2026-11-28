import { useEffect, useState } from 'react';
import './workspace-dialog.css';

const initialValues = {
  clientName: '', email: '', phoneNumber: '',
  name: '', clientId: '', description: '',
  title: '', text: '', projectId: '', meetingMode: 'Online', meetingAt: '',
};

export default function WorkspaceCreateDialog({ mode, clients = [], projects = [], busy = false, onClose, onSubmit }) {
  const [values, setValues] = useState(initialValues);
  const [error, setError] = useState('');
  const set = (key, value) => setValues((current) => ({ ...current, [key]: value }));

  useEffect(() => {
    const onKeyDown = (event) => { if (event.key === 'Escape' && !busy) onClose(); };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [busy, onClose]);

  const submit = async (event) => {
    event.preventDefault();
    setError('');
    try { await onSubmit(values); }
    catch (cause) { setError(cause?.data?.detail || cause?.data?.message || cause?.message || 'The request could not be completed.'); }
  };

  const headings = {
    project: ['New project', 'Create a company-scoped project record.'],
    client: ['New client', 'Add a client to your company workspace.'],
    meeting: ['New meeting note', 'Save the original meeting content for knowledge extraction.'],
  };
  const [title, description] = headings[mode] || headings.project;
  const needsClient = mode === 'project' || mode === 'meeting';
  const needsProject = mode === 'meeting';

  return (
    <div className="st-dialog-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget && !busy) onClose(); }}>
      <section className="st-dialog" role="dialog" aria-modal="true" aria-labelledby="st-dialog-title">
        <header className="st-dialog__header">
          <div><span className="st-section-label">WORKSPACE ACTION</span><h2 id="st-dialog-title">{title}</h2><p>{description}</p></div>
          <button type="button" className="st-dialog__close" onClick={onClose} disabled={busy} aria-label="Close dialog">×</button>
        </header>
        <form className="st-dialog__form" onSubmit={submit}>
          {mode === 'client' && <>
            <label>Client name<input required maxLength={200} value={values.clientName} onChange={(event) => set('clientName', event.target.value)} placeholder="e.g. Atlas Software" autoFocus/></label>
            <div className="st-dialog__row"><label>Email <span>Optional</span><input type="email" maxLength={254} value={values.email} onChange={(event) => set('email', event.target.value)} placeholder="contact@company.com"/></label><label>Phone <span>Optional</span><input type="tel" maxLength={50} value={values.phoneNumber} onChange={(event) => set('phoneNumber', event.target.value)} placeholder="+20 ..."/></label></div>
          </>}
          {mode === 'project' && <>
            <label>Project name<input required maxLength={200} value={values.name} onChange={(event) => set('name', event.target.value)} placeholder="e.g. ERP Platform" autoFocus/></label>
            <label>Client<select required value={values.clientId} onChange={(event) => set('clientId', event.target.value)}><option value="">Select a client</option>{clients.map((client) => { const id = client.clientId ?? client.ClientId ?? client.id ?? client.Id; const name = client.clientName ?? client.ClientName ?? client.name ?? client.Name ?? id; return <option key={id} value={id}>{name}</option>; })}</select></label>
            <label>Description <span>Optional</span><textarea rows="3" maxLength={4000} value={values.description} onChange={(event) => set('description', event.target.value)} placeholder="What is this project about?"/></label>
            {!clients.length && <p className="st-dialog__hint">Create a client first. The Projects API requires a valid client ID.</p>}
          </>}
          {mode === 'meeting' && <>
            <label>Meeting title<input required maxLength={200} value={values.title} onChange={(event) => set('title', event.target.value)} placeholder="e.g. Sprint planning" autoFocus/></label>
            <div className="st-dialog__row"><label>Client<select required value={values.clientId} onChange={(event) => { set('clientId', event.target.value); set('projectId', ''); }}><option value="">Select a client</option>{clients.map((client) => { const id = client.clientId ?? client.ClientId ?? client.id ?? client.Id; const name = client.clientName ?? client.ClientName ?? client.name ?? client.Name ?? id; return <option key={id} value={id}>{name}</option>; })}</select></label><label>Project<select required value={values.projectId} onChange={(event) => set('projectId', event.target.value)}><option value="">Select a project</option>{projects.filter((project) => String(project.clientId ?? project.ClientId) === values.clientId).map((project) => { const id = project.projectId ?? project.ProjectId ?? project.id ?? project.Id; const name = project.projectName ?? project.ProjectName ?? project.name ?? project.Name ?? id; return <option key={id} value={id}>{name}</option>; })}</select></label></div>
            <div className="st-dialog__row"><label>Meeting type<select value={values.meetingMode} onChange={(event) => set('meetingMode', event.target.value)}><option value="Online">Online</option><option value="InPerson">In person</option></select></label><label>Meeting date<input type="datetime-local" required value={values.meetingAt} onChange={(event) => set('meetingAt', event.target.value)}/></label></div>
            <label>Original meeting notes<textarea required rows="6" maxLength={256000} value={values.text} onChange={(event) => set('text', event.target.value)} placeholder="Paste the original meeting notes or transcript…"/></label>
            <p className="st-dialog__hint">The original text is saved as a Meeting Notes knowledge source. Extraction and review follow the backend processing workflow.</p>
          </>}
          {error && <div className="st-dialog__error" role="alert">{error}</div>}
          <footer className="st-dialog__footer"><button type="button" className="st-dialog__cancel" onClick={onClose} disabled={busy}>Cancel</button><button type="submit" className="st-dialog__submit" disabled={busy || (mode === 'project' && !clients.length) || (mode === 'meeting' && (!clients.length || !projects.length))}>{busy ? 'Saving…' : mode === 'meeting' ? 'Save meeting note' : mode === 'client' ? 'Create client' : 'Create project'}</button></footer>
        </form>
      </section>
    </div>
  );
}
